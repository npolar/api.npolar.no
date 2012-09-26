module Npolar
  module Rack
    class OaiSkeleton

      attr_accessor :request, :provider

      def initialize(app, options)
        @app = app
        unless options[:provider]
          raise ArgumentError "Missing provider (instance of ::OAI::Provider::Base)"
        end
        @provider = options[:provider]
      end

      def call(env)        
        request = Rack::Request.new(env)
        response =  provider.process_request(request.params)
        [200, {"Content-Type" => "application/xml"}, [response]]
      end
    end
  end
end