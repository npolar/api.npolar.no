require "gcmd/dif"
require "yajl/json_gem"

module Metadata
  module Rack
    class SaveGcmdDif
      
      def initialize(app)
        @app = app
      end

      def call(env)
                
        @request = ::Rack::Request.new(env)
         
        if @request.put? || @request.post?          
          if @request.env["CONTENT_TYPE"] == "application/xml"
          
            body = @request.body.read
            
            dif = Gcmd::Dif.new()
            json = dif.load_xml( body )

            if json.class == Array
              json.each do | document |                
                build_request( env, document )                 
              end              
              json = nil
            end            
            
            return build_request( env, json )
            
          end      
        end
        
        @app.call(env)
        
      end
      
      def build_request( env, body )
        
        unless body.nil?         
          
          json = body.to_json.to_s
            
          env["REQUEST_METHOD"] = "PUT" if env["REQUEST_METHOD"] == "POST"          
          env["PATH_INFO"] = "/" + uuid( body["Entry_ID"] )  
          env["CONTENT_TYPE"] = "application/json"
          env["CONTENT_LENGTH"] = json.bytesize.to_s          
          env["rack.input"] = ::Rack::Lint::InputWrapper.new( StringIO.new( json ) )
          
          @app.call(env)
        else
          [201, {"Content-Type" => "text/html"}, ["Successfully imported OAI document.\n"]]
        end
        
      end
      
      def uuid( key )
        UUIDTools::UUID.sha1_create( UUIDTools::UUID_DNS_NAMESPACE, @request.url + key )
      end
      
    end
  end
end
