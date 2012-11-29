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
        end
      end
      
      protected
      
      def format?(request)
        config[:format].include?(request.format) ? true : false
      end
      
      def content_type?(request)
        config[:type].each{ |regex| return true if request.env["CONTENT_TYPE"] =~ regex }
        false
      end
      
      def write?(request)
        ["PUT", "POST"].include?(request.request_method) ? true : false
      end
      
      def created?(status)
        status == 201 ? true : false
      end
      
    end    
  end  
end