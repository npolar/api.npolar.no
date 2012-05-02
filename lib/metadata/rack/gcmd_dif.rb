require_relative "../../gcmd/dif"

module Metadata
  module Rack
    class GcmdDif

      def initialize(app)
        @app = app

      end

      def call(env)
        request = ::Rack::Request.new(env)

        status, headers, body = @app.call(env)
        format = request.path_info.split(".").last

        # GET (DIF) XML
        if request.get? and status < 400 and format =~ /^(xml|dif)$/ 
          # Extract JSON response body - there must be a better way
          j = ""
          body.each  { |s| j += s }

          dif = Gcmd::Dif.new(j)
          xml = dif.to_xml

          headers["Content-Type"] = "application/xml"
          headers["Content-Length"] = xml.size.to_s
          [status, headers, [xml]]
        else
          [status, headers, body]
        end
      end

    end
  end
end
