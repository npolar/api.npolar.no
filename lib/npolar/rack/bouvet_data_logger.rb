module Npolar
  module Rack

    class BouvetDataLogger < Npolar::Rack::Middleware

      def condition?(request)
        create?(request)
      end

      def handle(request)
        log.info "@BouvetDataLogger"
        data = request.body.read

        request.env["rack.input"] = data
        app.call(request.env)
      end

      def create?(request)
        ["PUT", "POST"].include?(request.request_method)
      end

    end
  end
end
