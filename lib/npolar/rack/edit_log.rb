module Npolar
  module Rack

    # Store and index DELETE, POST, and PUT request and response
    #
    # use Npolar::Rack::EditLog,
    #     save: EditLog.save_lambda(
    #       uri: ENV["NPOLAR_API_COUCHDB"]||"http://user:password@localhost:5984",
    #       database: "api_editlog"
    #     ),
    #     index: EditLog.index_lambda,
    #     open: true
    class EditLog < Npolar::Rack::Middleware
      
      CONFIG = {
        edit: nil,
        save: nil,
        index: nil,
        open: nil
      }
      
      # See Npolar::Rack::Middleware
      def condition?(request)
        request.edit? and app.respond_to?(:call)
      end

      # Grab upstream response and store in storage layer and search engine
      def handle(request)
        response = app.call(request.env)

        begin
          edit = edit(request, response)

          save(edit)
          index(edit)

          log.info "#{request.request_method} #{request.path} [#{self.class.name}]"

        rescue => e
          log.error "#{request.request_method} #{request.path} [#{self.class.name}] failed: #{e}"
        end

        response
      end

      # Create edit hash like
      def edit(request, response)
        if not config[:edit].nil?
          return config[:edit].call(edit)
        end

        id = UUIDTools::UUID.random_create.to_s
        
        url = URI.parse(request.url)
        server = url.host
        port = url.port
        scheme = url.scheme

        # Grab ETag
        etag = nil
        if response.respond_to?(:header) and not response.header["ETag"].nil?
          etag = response.header["ETag"]
        end

        # Grab Location, force to absolute if relative
        location = nil
        if response.respond_to?(:header) and not response.header["Location"].nil?
          location = response.headers["Location"]
          if location != /^http/ and location =~ /^\//
            location = "#{scheme}://#{server}#{port != 80 ? ":#{port}" : ""}#{location}"
          end
        end

        # Grab status
        if response.respond_to?(:status)
          status = response.status
        else
          status = response[0]
        end

        # Grab response headers
        if response.respond_to?(:header)
          header = response.header
        else
          header = response[1]
        end

        # Authorization type
        authorization = nil
        if request.env.key? "HTTP_AUTHORIZATION"
          authorization = request.env["HTTP_AUTHORIZATION"].split(" ")[0]
        end

        edit = {
          id: id,
          server: server,
          method: request.request_method,
          endpoint: request.env["SCRIPT_NAME"],
          path: request.path.gsub(/\.#{request.format}$/, "").gsub(/\/$/, ""),
          request: {
 
            uri: request.url,
            format: request.format,
            mediatype: request.media_type,
            authorization: authorization,
            protocol: request.env["SERVER_PROTOCOL"],
            username: request.username,
            time: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
            ip: request.ip,
            body: request.body.read,
            header: {
              Accept: request.env["HTTP_ACCEPT"]
            }
          },
          response: {
            status: status,
            header: header,
            body: body(response, status, open?)

          },   
          severity: severity(status),
          open: open?
        }

        edit[:request][:header][:"Content-Type"] = request.env["CONTENT_TYPE"]
        edit[:request][:header][:"Content-Length"] = request.env["CONTENT_LENGTH"].to_i
        edit[:request][:header][:"User-Agent"] = request.user_agent
        edit
      end

      def body(response, status, open_data)
        
        if response.respond_to?(:body)
          body = response.body
        else
          body = response[2]
        end

        if body.respond_to? :join
          body = body.join("")
        end

        if body.is_a? StringIO
          body = body.read
        end
        
        if status >= 400
          body
        elsif true == open_data
          body     
        else
          ""
        end
      end

      def open?
        config[:open] == true
      end
      
      # http://tools.ietf.org/html/rfc5424#section-6.2.1
      #0       Emergency: system is unusable
      #1       Alert: action must be taken immediately
      #2       Critical: critical conditions
      #3       Error: error conditions
      #4       Warning: warning conditions
      #5       Notice: normal but significant condition
      #6       Informational: informational messages
      #7       Debug: debug-level messages
      def severity(status)
        case status
          when 100..199
            7
          when 200..299
            6
          when 300..399
            5
          when 400..499
            4
          when 500..599
            3
        end
      end

      protected

      def save(edit)
        if config[:save].respond_to? :call
          config[:save].call(edit)
        end
      end

      def index(edit)
        if config[:index].respond_to? :call
          config[:index].call(edit)
        end
      end



    end
  end
end
