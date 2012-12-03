module Npolar
  module Rack
    class DiskStorage < Npolar::Rack::Middleware
      
      CONFIG = {
        :format => [],
        :type => [],
        :file_root => "/mnt/api"
      }
      
      attr_accessor :document, :file
      
      def condition?(request)
        (format?(request) or content_type?(request)) and write?(request)
      end
      
      def handle(request)
        # Hold on to a copy of the data
        self.document = request.body.read
        request.env["rack.input"] = StringIO.new( document )
        
        # Pass the request down the middleware stack
        status, headers, body = app.call(request.env)
        
        # If 201 created store the source file to a parallel path on the file_root
        if created?(status)
          self.file = config[:file_root] + request.script_name + "/" + request.id + "." + request.format
          save_to_disk
        end
        
        # Pass the response further up the middleware stack
        [status, headers, body]
      end
      
      # Save file to the specified location on disk
      def save_to_disk
        begin
          File.open(file, "wb" ) do |tmp|
            tmp.puts document
          end
        rescue
          # What should happen?
          # Just Raise an Exception?
          # Leave data posted to database intact or remove since the chain wasn't completed?
          # If data is left require a repost when problem fixed to get source data?
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
        status == 201 ? true : false
      end
      
    end    
  end  
end