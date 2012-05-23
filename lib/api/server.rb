require "yajl/json_gem" # https://github.com/brianmario/yajl-ruby

module Api
  # API Server
  # HTTP/1.1 http://tools.ietf.org/html/rfc2616
  class Server

    attr_reader :collection

    attr_accessor :methods, :log

    # Default format
    FORMAT = "json"

    # Default header - and for errors, the only format
    HEADER = {
      "Content-Type"=> "application/json; charset=utf-8"
    }

    # Default acceptable methods
    METHODS = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT", "TRACE"]

    # HTTP/1.1 Status codes (@see #error_hash)
    STATUS = {
      200 => "OK",
      201 => "Created",
      202 => "Accepted",
      301 => "Moved Permanently",
      302 => "Found",
      304 => "Not Modified",
      307 => "Temporary Redirect",
      400 => "Bad Request",
      401 => "Unauthorized",
      404 => "Not Found",
      409 => "Conflict",
      410 => "Gone",
      411 => "Length Required",
      405 => "Method Not Allowed",
      500 => "Internal Server Error",
      503 => "Service Unavailable"
    }

    # Extract id from request
    def id request
      id = request.path_info.split("/")[1]
      
      if id =~ /[.]/
        id = id.split(".")[0]
      end
      
      id
    end

    # Extract format from request / collection
    def format request

      if request.path_info =~ /[.]/
        format = request.path_info.split(".")[1]
      elsif collection.respond_to? :formats and collection.formats.include? accept_format(request)
        format = accept_format(request) 
      elsif collection.respond_to? :default_format
        collection.default_format
      else
        format = FORMAT
      end
      format
    end

    def accept_format request

      return nil if request.env['HTTP_ACCEPT'].nil?

      format = request.env['HTTP_ACCEPT'].scan(/[^;,\s]*\/[^;,\s]*/)[0].split("/")[1]
      if format =~ /[+]/
        format = format.split("+")[0]
      end
      format
    end

    def initialize(app=nil)
      @app = app
      @methods = METHODS
    end

    # Rack application
    def call(env)
      env["HTTP_COOKIE"] = ""
      request = Rack::Request.new(env)
      handle(request)
    end

    def collection=collection
      if collection.respond_to? :get
        @collection = collection
      else
        raise Api::Exception.new("Bad collection, missing #get #{collection.inspect}")
      end
    end

    # Search request is any Grequest with
    # - GET parameter "q"
    def search_request? request
      if !request_id?(request) && request.request_method == "GET"
        return true
      end
      false
    end

    def request_id? request
      if request.path_info.split("/").size == 0
        return false
      end
      true
    end

    # Handle HTTP request and return HTTP response triplet (Rack-style)
    def handle(request)

      


      # Collection gateway set?
      if @collection.nil?
        return http_error(503)
      end

      # Check request syntax
      #unless readable_request?
      #  return http_error(400)
      #end
      # parseable_data?()
      # Check authorization
      unless authorized?
        return http_error(401)
      end

      # Check if HTTP method is allowed
      unless allowed_method? request.request_method
        return http_error(405)
      end

      #unless acceptable_format? request
      #  return http_error(406)
      #end 

      # Good to go - everything before *must* return on error (or raise Exception)
      begin

        headers = Rack::Utils::HeaderHash.new(request.env)
        #if PUT/POST
        body = request.body.read

        unless search_request?(request)

          id = id(request)
          @collection.format = format(request)

          response_status, response_headers, response_body = case request.request_method
            when "DELETE"  then @collection.delete(id, headers)
            when "GET"     then @collection.get(id, headers)
            when "HEAD"    then @collection.head(id, headers)
            when "OPTIONS" then @collection.options(id, headers)
            when "PATCH"   then @collection.patch(id, body, headers)
            when "POST"    then @collection.post(body, headers)
            when "PUT"     then @collection.put(id, body, headers)
            when "TRACE"   then @collection.trace(id, headers)
          end

        else
          response_status, response_headers, response_body = @collection.search
        end

        response = Rack::Response.new([], response_status, HEADER ) #(body=[], status=200, header={})
        # set 406 if collection.formats does not include the request format?

        unless response_headers["Content-Type"].nil?
          response["Content-Type"] = response_headers["Content-Type"]
        end

        if response["Content-Type"] !~ /; charset=/
          response["Content-Type"] +=  "; charset=utf-8"
        end

        response["Content-Length"] = response_body.respond_to?(:bytesize) ? response_body.bytesize.to_s : response_body.size.to_s
       
        response.write(response_body) unless request.request_method == "HEAD"

        response

      rescue => e
        puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        http_error(500, "Polar bears ate your request")
      ensure
        # log critical error
      end

    end

    def allowed_method? method
      http_methods.include? method
    end

    def http_methods
      @methods
    end

    def http_methods=methods
      @methods = methods
    end

    # true if collection can handle requested format
    # false if collection cannot handle requested format
    def acceptable_format? request
      collection.formats.include? format(request)
    end

    def authorized?
      true
    end

    protected

    def http_error(status, reason=nil)
      Rack::Response.new(error_hash(status, reason).to_json+"\n", status, HEADER )
    end

    def error_hash(status, reason=nil)
      if reason.nil?
        reason = STATUS[status]
      end
      klass = case status.to_i
        when 100..199 then "Informational"
        when 200..299 then "Successful"
        when 300..399 then "Redirection"
        when 400..499 then "Client Error"
        when 500..599 then "Server Error"
        else "Unknown"
      end

      {"error"=>{"status"=>status, "reason"=>reason, "class" => klass}}

    end

  end
end
