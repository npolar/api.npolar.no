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
        
        # Ask storage for the current document
        status, headers, body = config[:data_storage].get(@doc_id) unless @doc_id.nil?
        
        # Load the current version of the document if it exists
        # otherwise set the current version to an empty hash
        status == 200 ? @current = Yajl::Parser.parse(body) : @current = {}
        
        # Pass request down the middleware stack
        response = app.call(@env)
        
        # Set id to the new document id on create
        @doc_id ||= Yajl::Parser.parse(response.body.first)["_id"] 
        
        # When all operations are successfull save changes
        if [200, 201].include?(response.status)
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
          
          log.info "@ChangeLogger: Saving changes ==> #{changes}"
          status, headers, body = config[:diff_storage].put(change_id, changes)
          log.error "@ChangeLogger: ERROR! received #{status} while saving" unless [200, 201].include?(status)
        end
        
        response        
      end
      
      protected
      
      def change?(verb)
        ["PUT", "POST", "DELETE"].include?(verb)
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
      
      def details
        {
          :document => @doc_id,
          :workspace => workspace,
          :collection => collection,
          :additional_namespaces => additional_namespaces,
          :changes => [change_log]
        }
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
      
    end
  end
end
