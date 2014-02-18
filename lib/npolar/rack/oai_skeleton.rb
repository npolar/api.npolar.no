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
        # 3.1.2.1 Content-Type
        # The Content-Type returned for all OAI-PMH requests must be text/xml.
        # http://www.openarchives.org/OAI/2.0/openarchivesprotocol.htm
        [200, {"Content-Type" => "text/xml"}, [response]]
      end
    end
  end
end