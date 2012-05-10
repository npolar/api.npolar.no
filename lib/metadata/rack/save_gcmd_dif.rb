require "gcmd/dif"
require "yajl/json_gem"

module Metadata
  module Rack
    class SaveGcmdDif
      
      def initialize(app)
        @app = app
      end

      def call(env)
                
        request = ::Rack::Request.new(env)
         
        if request.put? || request.post?          
          if request.env["CONTENT_TYPE"] == "application/xml"
          
            body = request.body.read
            
            dif = Gcmd::Dif.new()
            json = dif.load_xml( body )

            if json.class == Array
              json.each do | document |                
                build_request( env, document )                 
              end              
              json = nil
            end            
            
            build_request( env, json )
            
          end      
        end
        
        @app.call(env)
        
      end
      
      def build_request( env, body )
        
        unless body.nil?
          json = body.to_json.to_s
            
          env["CONTENT_TYPE"] = "application/json"
          env["CONTENT_LENGTH"] = json.bytesize.to_s          
          env["rack.input"] = ::Rack::Lint::InputWrapper.new( StringIO.new( json ) )
          
          @app.call(env)
        else
          [201, {"Content-Type" => "text/html"}, ["OAI import succesful"]]
        end
        
      end      
    end
  end
end
