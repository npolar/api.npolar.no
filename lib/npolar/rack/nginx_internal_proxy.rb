module Npolar
  module Rack
    class NginxInternalProxy < Npolar::Rack::Middleware

      CONFIG = {
        :proxy_path => nil
      }

      def condition?(request)
        ['GET', 'HEAD'].include?(request.request_method) && (request.headers['HTTP_ACCEPT'] == "application/json" || request.format == "json")
      end

      def handle(request)
        log.info "Nginx internal redirect! #{self.class.to_s}"
        [ 200, {'X-Accel-Redirect' => "/#{config[:proxy_path]}/#{id}"}, [] ]
      end

    end
  end
end