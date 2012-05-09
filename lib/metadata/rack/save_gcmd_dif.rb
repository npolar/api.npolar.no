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
            
            json = json.to_json.to_s
            
            env["CONTENT_TYPE"] = "application/json"
            env["CONTENT_LENGTH"] = json.bytesize.to_s
            
            input = ::Rack::Lint::InputWrapper.new( StringIO.new( json ) )
            
            env["rack.input"] = input            
            
          end          
          
        end
        
        @app.call(env)        
        
      end      
    end
  end
end
