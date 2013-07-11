module Npolar
  module Rack
    class GeoJSON < Npolar::Rack::Middleware

      CONFIG = {
        :headers => { "Content-Type" => "application/json; charset=utf-8" }
      }
        
      def condition?(request)
        true == (request.json? and ["GET"].include?(request.request_method))
      end
      
      def handle(request)
        [200, headers("json"), [request.env.to_json]]
      end
      
    end
  end
end