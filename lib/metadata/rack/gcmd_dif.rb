require "gcmd/dif"

module Metadata
  module Rack
    class GcmdDif
      
      REQUEST_PATH_WITH_ID = /^\/([^.]+)\.(\w+)/

      def initialize(app)
        @app = app
      end

      def call(env)
        request = ::Rack::Request.new(env)

        status, headers, body = @app.call(env)
              
        if request.path_info =~ REQUEST_PATH_WITH_ID
          
          if status < 400
            
            format = request.path_info.split(".").last           

            if format != "json"
              if format =~ /^(xml|dif)$/             
              
                if request.get?
                  # Extract JSON response body - there must be a better way
                  j = ""
                  body.each  { |s| j += s.to_s }
        
                  dif = Gcmd::Dif.new(j)
                  body = dif.to_xml        
                
                  headers["Content-Type"] = "application/xml"  
                  headers["Content-Length"] = body.bytesize.to_s
                  
                  body = [body]
                  
                elsif request.head?
                  headers["Content-Type"] = "application/xml"
                  body = [""]
                end                
              else              
                status = 406              
              end
            end
          end
        end
        
        if request.head?
          body = [""]
        end

        [status, headers, body]
        
      end
    end
  end
end
