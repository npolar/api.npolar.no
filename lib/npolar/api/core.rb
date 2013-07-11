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
      :headers => { "Content-Type" => "application/json; charset=utf-8" },
      :before => nil,
      :after => nil,
      :storage => nil,
      :log => nil,
      :methods => ["DELETE", "GET", "HEAD", "POST", "PUT"], # Allowed HTTP methods,
      
    }

    # Rack application
    # @param env
    # @return Npolar::Rack::Response | |[status, headers, body#each]
    def call(env)
      
      begin

        @request = Rack::Request.new(env) # <Npolar::Rack::Request>
        # Delegete everything except "html" to #handle
        if request.read? and request.format == "html" and @app.respond_to? :call
          @app.call(env)
        else
          handle(request)
        end

      rescue Npolar::Auth::Exception => e
        http_error(403, "Polar bears ate your request")
      # 500 Internal Server Error
      rescue => e
        log.fatal e.class.name+": "+e.message
        log.fatal "Backtrace:\n\t#{e.backtrace.join("\n\t")}" #except e.class == Npolar::Auth::Exception
        http_error(500, "Polar bears ate your request")
      end

    end

    # Handle HTTP request and return HTTP response triplet (Rack-style)
    # @return Npolar::Rack::Response or [status, headers, body#each]
    def handle(request)

      log.debug self.class.name+"#handle #{request.request_method} #{request.url}"

      if storage.nil? 
        return http_error(501, "No storage set for API endpoint, cannot handle request")
      end

      # 405 Method not allowed
      unless method_allowed? request.request_method
        return http_error(405, "The following HTTP methods are allowed: #{methods.join(", ")}")
      end

      # GET, HEAD and POST are the only method where id can be blank
      unless /(GET|HEAD|POST)/ =~ request.request_method
        unless request.id?
          return http_error(400, "Missing or blank request id, cannot handle #{request.request_method} request")
        end
      end

      #414 Request-URI Too Long?

      request = before(request)

      if ["GET", "HEAD", "DELETE"].include? request.request_method
        # 404 / 410 Gone?
        # 412 Precondition Failed?
        # 414 Request-URI Too Long?

        # 406 Not Acceptable
        unless acceptable? request.format
          return http_error(406, "Unacceptable format '#{format}', this API endpoint supports the following #{request.request_method} formats: #{formats.join(",")}")
        end
        
      elsif ["PUT", "POST"].include? request.request_method

        log.debug "Accepts(#{request.media_type})? #{accepts? request.media_type}"

        document = request.body.read 
        request.body.rewind # rewind is necessary for request.body is empty after #read
        log.debug "#{request.request_method} #{request.media_format} request (#{document.bytesize} bytes)"
        
        # 411 Length Required?
        # Insist on Content-Length on chunked transfers
        # if headers["Content-Length"].nil? or headers["Content-Length"].to_i <= 0
        #  return http_error(411)
        # end

        # FIXME 413 Request Entity Too Large
        # FIXME PUT with no etag/revision and 409 => new status code for conditional PUT?

        # 415 Unsupported Media Type
        unless accepts? request.media_type
          return http_error(415, "Unsupported: #{request.media_type}. Acceptable POST/PUT media types are: '#{accepts.join(", ")}'")
        end

        #400 Bad Request
        if 0 == document.bytesize or /^\s+$/ =~ document
          return http_error(400, "#{request.request_method} document with no body")
        end

        #422 Unprocessable Entity (WebDAV; RFC 4918)
        unless valid?(document, request.request_method)
          log.warn "#{request.request_method} #{request.url} = 422. Errors: #{errors.to_json}"
          return http_error(422, errors)
        end 

      end
      
      response = case request.request_method
        when "DELETE"  then storage.delete(id, params)
        when "GET"     then storage.get(id, params)
        when "HEAD"    then storage.head(id, params)
        when "POST"    then storage.post(document, params)
        when "PUT"     then storage.put(id, document, params)
      end

      response = after(request, response)

      if response.is_a? Rack::Response or response.respond_to?(:body)
        if response.respond_to?(:body) and response.body.is_a? Hash
          response.body = body.to_json
        end
      elsif response.respond_to?(:each)
        if 1 == response.size and response[0].is_a? Hash
          response[0]= response[0].to_json
        end
        # else: OK
      else
        raise "Bad response"
      end
    
      status, headers, body = response
      log.debug "Core headers: #{status} #{headers}"
      Rack::Response.new(body, status, headers)

    end

    # @return Boolean
    # On GET/HEAD/DELETE
    # * true  if endpoint can deliver requested format
    # * false if endpoint cannot deliver requested format
    def acceptable? format
     
      if "*" == format
        true
      else
        formats.include? format
      end
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

    protected

    def errors
      @errors ||= nil
    end

    # @return Array
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

    def before(request)
      if config[:before].nil? or [] == config[:before]
        return request
      end
      if config[:before].respond_to? :call
        config[:before] = [config[:before]]
      end
      config[:before].each_with_index do |before, i|
        log.debug "Before #{request.request_method} #{i} (#{before})"
        request = before.call(request)
      end
      request
      
    end

    def after(request, response)
      if config[:on].respond_to? :call
        log.debug "On #{request.request_method} (#{config[:on]})"
        config[:on].call(request, response)
      else
        response
      end
    end

    # @return Boolean
    def valid? document, context
      if storage.respond_to? :valid?
        v = storage.valid? document, context
        if false == v and storage.respond_to? :errors
          @errors = storage.errors
        end
        v
      else
        true
      end
    end

  end
  
  # Npolar::Api::Exception
  class Exception < ::Exception
  end

  end
end
