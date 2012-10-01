module Npolar
  module Api
  # Npolar::Api::Core
  #
  # Rack class for running a REST-style HTTP document API
  #
  # @link https://github.com/npolar/api.npolar.no/wiki/Core
  # @link Rack http://rack.rubyforge.org/doc/SPEC.html
  # @link HTTP/1.1 http://tools.ieetf.org/html/rfc2616 | http://www.w3.org/Protocols/rfc2616/rfc2616.html
  class Core < Rack::Middleware

    # Default configuration
    CONFIG = {
      :accepts => lambda { |storage| storage.respond_to?(:accepts) ? storage.accepts : [] }, # Accepted formats (incoming)
      :formats => lambda { |storage| storage.respond_to?(:formats) ? storage.formats : [] }, # Supported formats (outgoing)
      :storage => nil,
      :log => nil,
      :methods => ["DELETE", "GET", "HEAD", "POST", "PUT"], # Allowed HTTP methods,
      :headers => { "Content-Type" => "application/json; charset=utf-8" }
    }

    # Rack application
    # @param env
    # @return [status, headers, body#each]
    def call(env)
      
      begin
        env["HTTP_COOKIE"] = ""
        @request = Rack::Request.new(env) # <Npolar::Rack::Request>

        handle(request)

      rescue => e

        log.fatal e.class.name+": "+e.message
        log.fatal "Backtrace:\n\t#{e.backtrace.join("\n\t")}"

        http_error(500, "Polar bears ate your request")

      end
    end

    # Handle HTTP request and return HTTP response triplet (Rack-style)
    # @return Npolar::Rack::Response or [status, headers, body#each]
    def handle(request)

      log.debug self.class.name+"#handle [#{request.request_method} #{request.url}] #{::DateTime.now.xmlschema(6)}"

      if storage.nil?
        return http_error(501, "No storage set for API endpoint, cannot handle request")
      end

      unless method_allowed? request_method
        return http_error(405, "The following HTTP methods are allowed: #{methods.join(", ")}")
      end

      # GET, HEAD and POST are the only method where id can be blank
      unless /(GET|HEAD|POST)/ =~ request_method
        unless request.id?
          return http_error(400, "Missing or blank request id, cannot handle #{request_method} request")
        end
      end

      if ["GET", "HEAD", "DELETE"].include? request_method
        # 404 => 410 Gone
        # 412 Precondition Failed
        # 414 Request-URI Too Long
        unless acceptable? format
          return http_error(406, "Unacceptable format '#{format}', this API endpoint supports the following #{request_method} formats: #{formats.join(",")}")
        end
      elsif ["PUT", "POST"].include? request_method
        # 411 Length Required
        # FIXME Insist on Content-Length on chunked transfers
        # if headers["Content-Length"].nil? or headers["Content-Length"].to_i <= 0
        #  return http_error(411)
        # end
        # FIXME max content length
        # FIXME PUT with no etag/revision and 409 => new status code for conditional PUT?

        unless accepts? request.media_format
          return http_error(415, "This API endpoint does not accept documents in '#{request.media_format}' format, acceptable #{request_method} formats are: '#{accepts.join(", ")}'")
        end

        document = request.body.read # request.body is now empty
        if 0 == document.bytesize or /^\s+$/ =~ document
          return http_error(400, "#{request_method} document with no body")
        end

        
        # FIXME 413 Request Entity Too Large
        # 414 Request-URI Too Long

        unless valid? document
          return http_error(422)
        end 

      end
      
      status, headers, body = case request_method
        when "DELETE"  then storage.delete(id, params)
        when "GET"     then storage.get(id, params)
        when "HEAD"    then storage.head(id, params)
        when "POST"    then storage.post(document, params)
        when "PUT"     then storage.put(id, document, params)
      end

      log.debug "#{status} #{headers} #{::DateTime.now.xmlschema(6)}"

      Rack::Response.new(body, status, headers)

    end

    # @return Boolean
    # On GET/HEAD/DELETE
    # * true  if endpoint can deliver requested format
    # * false if endpoint cannot deliver requested format
    def acceptable? format
      formats.include? format
    end

    # @return Boolean
    # On POST/PUT
    # * true if endpoint can receive requested format
    # * false if collection cannot receive requested formar
    def accepts? format
      accepts.include? format
    end

    # @return Array
    def accepts
      force_array(config[:accepts], storage)
    end

    # @return String
    def format
      request.format.empty? ? formats.first : request.format
    end

    # @return Array
    def formats
      force_array(config[:formats], storage)
    end

    # @return Array
    def methods
      force_array(config[:methods])
    end

    # @return Boolean
    def method_allowed? method
      methods.include? method
    end

    # @return Storage
    def storage
      @storage ||= config[:storage]
    end

    # Storage setter
    # @return void
    def storage=storage
      @storage=storage
    end

    # @return Boolean
    def valid? document
      if storage.respond_to? :valid?
        storage.valid? document
      else
        true
      end
    end
    
    protected

    # @return Boolean
    def force_array(v, with=nil)
      with = with.nil? ? request : with

      a = case v
        when String then [v]
        when Proc then v.call(with)
        when Array then v
        else []
      end
      if [] == a and v.respond_to?(:call)
        a = v.call(with)
      end
      a
    end

    def log
      config[:log] ||= Api.log
    end

  end

  class Exception < Exception
  end

  end
end