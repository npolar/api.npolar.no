require 'pp'

# ALWAYS POST with an extension like .nc
module Npolar
  module Rack
    class DiskStorage < Npolar::Rack::Middleware
      
      CONFIG = {
        :format => [],
        :type => [],
        :file_root => "/mnt/api",
      }
      
      attr_accessor :document, :file
      
      def condition?(request)
        puts format?(request)
        puts content_type?(request)
        return (request.request_method == "DELETE" or format?(request) or content_type?(request))
      end

      def handle(request)
        case request.request_method
          when "DELETE" then handle_delete(request)
          when "POST", "PUT" then handle_create(request)
          when "GET" then handle_get(request)
        end
      end

      # XXX needs to be made more robust
      def handle_get(request)
        begin
          resource = request.env["REQUEST_URI"].split("/").last()
          id = File.basename(resource, '.*')
          filepath = path(id, request)

          if !File.exist?(filepath)
            return [404, {"Content-type" => "application/json"}, StringIO.new({ "error" => "Resource not found"}.to_json)]
          else
            # read from the fs 
            content = File.open(filepath, "rb" ) { |file| file.read }

            return [200, {"Content-type" => request.env["CONTENT_TYPE"]}, StringIO.new(content)]
          end
        rescue => e
          log.debug e
          return [500, {"Content-type" => "application/json"}, StringIO.new({ "error" => "Error processing request"}.to_json)]
        end

      end

      def handle_delete(request)
        begin
           # Pass the request down the middleware stack
          response = app.call(request.env)
          body = response.body[0]

          json = Yajl::Parser.parse(body)
          if !json.has_key?("id") or json["id"].empty?
            raise "id needs to be supplied by upstream middleware"
          end

          log.debug "handle_delete: #{json["id"]}"

          # delete path containing all document files
          FileUtils.rm_rf(doc_root(json["id"]))
          
        rescue => e
          log.debug e
        end 

        [response.status, response.headers, StringIO.new(body)]
      end

      def handle_create(request)
        begin
          # Hold on to a copy of the data
          content = request.body.read
          request.env["rack.input"] = StringIO.new(content)
          
          # Pass the request down the middleware stack
          response = app.call(request.env)
          body = response.body[0]

          # parse response body 
          json = Yajl::Parser.parse(body)
          if !json.has_key?("id") or json["id"].empty?
            raise "id needs to be supplied by upstream middleware"
          end

          # write to fs
          if created?(response.status)
            save_to_disk(path(json["id"], request), content)
          end
        rescue => e
          log.fatal "Backup of document failed: handle"
          log.fatal e

          # stop show
          raise Exception
        end
        
        [response.status, response.headers, StringIO.new(body)]
      end

      # Save file to the specified location on disk
      def save_to_disk(path, content)
        log.debug "save_to_disk #{path}, #{content.length}"
        begin
          # create directories if they don't exist
          FileUtils.mkdir_p(File.dirname(path))

          # write the document
          File.open(path, "wb" ) do |file|
            file.write(content)
          end

        rescue => e
          log.fatal "Backup of document failed: save_to_disk"
          log.fatal e

          # should stop the show if we can't backup our data
          raise Exception
        end
      end
      
      protected
      
      # Check if the format for the request matches the configured formats
      def format?(request)
        config[:format].include?(request.format)
      end
      
      # Check if the request content-type matches any of the configured content types
      def content_type?(request)
        config[:type].each{ |regex| return true if request.env["CONTENT_TYPE"] =~ regex }
        false
      end
      
      # Check if this is a write request
      def write?(request)
        ["PUT", "POST"].include?(request.request_method)
      end
      
      # Check if 201 Created
      def created?(status)
        [201, 200].include?(status)
      end

      def path(id, request)
        doc_root(id) + "/source/doc." + request.format
      end

      def doc_root(id)
        config[:file_root] + "/" + id 
      end

    end    
  end  
end
