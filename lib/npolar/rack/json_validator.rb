require "json-schema"

module Npolar
  module Rack
    class JsonValidator < Npolar::Rack::Middleware
      
      CONFIG = {
        :schema => []
      }
        
      def condition?(request)
        return true if json?(request) and ["PUT", "POST"].include?(request.request_method)
        false
      end
      
      def handle(request)
        data = request.body.read
        
        if valid?( data )
          request.env['rack.input'] = StringIO.new( data )
          app.call( request.env )
        else
          self.request = request
          error = error_hash(406, "Invalid json")
          error["errors"] = validate(data)
          error = StringIO.new( error.to_json )
          
          [406, {"Content-Type" => "application/json"}, error]
        end        
      end
      
      def valid?(data)
        config[:schema].each{ |schema| return true if JSON::Validator.validate(schema, data)}
        false
      end
      
      def validate(data)
        errors = []
        config[:schema].each{ |schema| errors << {schema => JSON::Validator.fully_validate(schema, data)}}
        errors
      end
      
      protected
      
      def json?(request)
        return true if request.format == "json" or request.content_type =~ /application\/json/  
        false
      end
      
    end
  end
end