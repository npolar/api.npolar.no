# encoding: utf-8

require 'hashdiff'

module Npolar
  module Rack
    class ChangeLogger < Npolar::Rack::Middleware
      
      include Npolar::Api
     
      CONFIG = {
        :data_storage => nil,
        :diff_storage => nil
      }
      
      def condition?(request)
        change?(request.request_method)
      end
      
      def handle(request)
        @request = request
        @env = request.env
        @doc_id = request.id
        
        # Grab the updated document
        @updated = Yajl::Parser.parse(request.body.read)
        @updated.nil? ? @updated = {} :
        request.body.rewind
        
        unless batch? && create?
          response = update_single
        else
          response = update_multiple
        end
        
        response
      end
      
      protected
      
      def update_single
        # Ask storage for the current document
        status, headers, body = config[:data_storage].get(@doc_id) unless @doc_id.nil? || @doc_id.empty?
        
        # Load the current version of the document if it exists
        # otherwise set the current version to an empty hash
        status == 200 ? @current = Yajl::Parser.parse(body) : @current = {}
        
        # Pass request down the middleware stack
        response = app.call(@env)
        
        # When all operations are successfull save changes
        if success?(response.status)
        
          # Set id to the new document id on create
          @doc_id ||= Yajl::Parser.parse(response.body.first)["_id"] 
          
          # Get the past changes for this record
          status, headers, body = config[:diff_storage].get(change_id)
          
          # If a change log exists get the existing log
          # and add in any new changes. Otherwise create
          # a new change log.
          if status == 200
            changes = Yajl::Parser.parse(body)
            changes["changes"] << change_log
          else
            changes = details
          end
          
          log.info "@ChangeLogger: Saving changes to #{change_id} ==> #{changes}"
          status, headers, body = config[:diff_storage].put(change_id, changes)
          log.error "@ChangeLogger: ERROR! received #{status} while saving" unless success?(status)
        end
        
        response
      end
      
      def update_multiple
        log.info "@ChangeLogger: About to save changes for multiple documents"
        
        update_batch = @updated
        
        # Get ids for documents in the batch        
        original_keys = update_batch.map{|doc| doc["_id"] ||= doc["id"]}
        
        # Do a bulk request for current documents
        status, headers, body = config[:data_storage].post({:keys => original_keys}.to_json)
        
        # Extract documents from the bulk response
        current_batch = extract_docs(body)
        
        # Send request down the stack
        response = app.call(@env)
        
        if success?(response.status)
          
          # Get all the keys from the response
          response_keys = Yajl::Parser.parse(response.body.first)['response']['ids']
          
          # Map the document keys to the keys for the change log
          # If no document key was available in the post data
          # get the newly created one from the reponse
          change_keys = []
          original_keys.each_with_index do |key, i|
            if key.nil?
              @doc_id = original_keys[i] = response_keys[i]
            else
              @doc_id = key
            end
            
            change_keys << change_id
          end
          
          req = {:keys => change_keys}
          
          # Batch get any changes already in the database
          status, headers, body = config[:diff_storage].post(req.to_json)
          
          # Get the actual logs from the response
          change_logs = extract_docs(body)
          
          # Merge changes or create a new log
          update_batch.each_with_index do |update, i|
            
            @updated = update
            @current = current_batch[i]
            @doc_id = original_keys[i]
            
            unless change_logs[i] == {}
              change_logs[i]["changes"] << change_log
            else
              new_log = details
              new_log["id"] = change_keys[i]
              change_logs[i] = new_log
            end
          end
          
          # Do a batch post with all the changes
          status, headers, body = config[:diff_storage].post(change_logs.to_json)
          log.info "@ChangeLogger: Batch save exited with status code ==> #{status}"
        end
        
        response
      end
      
      def change?(verb)
        ["PUT", "POST", "DELETE"].include?(verb)
      end
      
      def batch?
        @updated.is_a? Array
      end
      
      def create?
        return true if @request.request_method == "POST"
        false
      end
      
      def success?(status)
        [200, 201].include?(status)
      end
      
      def details
        {
          :document => @doc_id,
          :workspace => workspace,
          :collection => collection,
          :additional_namespaces => additional_namespaces,
          :changes => [change_log]
        }
      end
      
      def change_log
        {
          :username => @request.username,
          :action => @request.request_method,
          :time => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
          :diff => diff
        }
      end
      
      def diff
        HashDiff.diff(@current, @updated)
      end
      
      # Every document has a dedicated change file based on
      # it's workspace collection and id.
      def change_id
        uuid(workspace + collection + @doc_id)
      end
      
      # The first element of the result array is the workspace.
      def workspace
        namespaces[0]
      end
      
      # The second element of the result array is the collection.
      def collection
        namespaces[1]
      end
      
      # Get additional namespaces
      def additional_namespaces
        extra = ""        
        i = 2
        
        until i == namespaces.size
          extra += "/" + namespaces[i]
          i += 1
        end unless namespaces.size < 1
        
        extra
      end
      
      # Get the namespaces from the path
      def namespaces
        names = path.split("/").drop(1)
        
        unless names.empty?
          if names.size > 1
            return names
          else
            return names.push("") # Add a blank entry for collection and return
          end
        else
          return ["", ""] #return a blank array for workspace and collection
        end
        
      end
      
      # Get the path information without ID and paramters
      def path
        return @env["REQUEST_PATH"].gsub(/#{@env["PATH_INFO"]}/, "") unless @env["PATH_INFO"] == '/'
        @env["REQUEST_PATH"][0..-2]
      end
      
      # Gets the actual documents from a bulk response and
      # return an empty Hash for non exisiting documents
      def extract_docs(bulk)
        rows = Yajl::Parser.parse(bulk)["rows"]
        documents = rows.map {|row| row['doc'] ||= {} }
      end
      
    end
  end
end
