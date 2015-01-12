# encoding: utf-8
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
        if request.read? and formats.include?("html") and request.format == "html" and @app.respond_to? :call
          @app.call(env)
        else
          handle(request)
        end

      rescue Npolar::Auth::Exception => e
        http_error(403)
      rescue => e
        log.fatal e.class.name+": "+e.message
        log.fatal "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        http_error(500, "Polar bears ate your request") # 500 Internal Server Error
      end

    end

    # Handle HTTP request and return HTTP response triplet (Rack-style)
    # @return Npolar::Rack::Response or [status, headers, body#each]
    def handle(request)
      log.debug self.class.name+"#handle #{request.request_method} #{request.url}"

      if storage.nil?
        return http_error(501, "No storage set for API endpoint, cannot handle request")
      end

      request = before(request)

      # 405 Method not allowed
      # The response MUST include an Allow header containing a list of valid methods for the requested resource.
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
      if ["GET", "HEAD", "DELETE"].include? request.request_method
        # 404 / 410 Gone?
        # 412 Precondition Failed?
        
        # 406 Not Acceptable ?
        # Only run the check if the endpoint supports multiple formats and
        # the user supplied .format extension
        if formats.size > 1 and request.path_info =~ /\.\w+/
          unless acceptable? request.format
            return http_error(406, "Unacceptable format '#{format}', this API endpoint supports the following #{request.request_method} formats: #{formats.join(",")}")
          end
        end
        
      elsif ["PUT", "POST"].include? request.request_method
        #log.debug "Accepts(#{request.media_type})? #{accepts? request.media_type}"
        # 415 Unsupported Media Type
        unless accepts? request.media_type
          return http_error(415, "Unsupported: #{request.media_type}. Acceptable POST/PUT media types are: '#{accepts.join(", ")}'")
        end
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
      
     before_time = Time.now
      
      # @todo move all methods into core#{verb}
      response = case request.request_method
        when "DELETE"  then storage.delete(id, params)
        when "GET"     then storage.get(id, params) # FIXME Handle empty id
        when "HEAD"    then storage.head(id, params)
        when "OPTIONS" then options
        when "POST"    then storage.post(document, params)
        when "PUT"     then storage.put(id, document, params)
      end
      
      response = after(request, response)

      status, headers, body = response

      log.info "#{request.request_method} #{request.path} [Core]: #{status} #{headers.to_s} took: #{Time.now - before_time}"
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
    
    # OPTIONS
    def options
      # OK <- An Allow header field MUST be present in a 405 (Method Not Allowed) response.
      # @todo <- If the Request-URI is an asterisk ("*"), the OPTIONS request is intended to apply to the server in general rather than to a specific resource.
      # OK <- If no response body is included, the response MUST include a Content-Length field with a field-value of "0".
      
      # Force "Allow" header 
      allow_header = lambda { |request, response|
        if not response.headers.key? "Allow"
          response.headers["Allow"] = methods.join(", ")
        end
        response
      }
      config[:after] = config[:after].nil? ? [] : config[:after] 
      config[:after] << allow_header
      
      if storage.respond_to?(:options)
        storage.options(id, params)
      else
        storage.head(id, params)
      end
      
      
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
      a.uniq.sort
    end

    def log
      config[:log] ||= Api.log
    end

    # After request
    # @return response Npolar::Rack::Response
    def after(request, response)
      
      # Force response to Rack::Response   
      if response.is_a? Rack::Response
        headers = response.headers
      elsif response.respond_to?(:size) and response.size == 3
         status, headers, body = response
         response = Rack::Response.new(body, status, headers)
      else
        raise "Bad response"
      end
      
      # Force UTF-8 on all responses
      if headers.key? "Content-Type" and headers["Content-Type"] != /; charset=utf-8$/
        content_type = headers["Content-Type"].split(";")[0]
        content_type += "; charset=utf-8"
      end

      response.header["Content-Type"] = content_type
      #response.header["Server"] = self.class.name+" "+response.header["Server"]      
    
      # Auto JSON from Hash
      if response.body.is_a? Hash 
        response.body = body.to_json
      end
  
      # After lambdas
      after = config[:after]||[]
      if storage.respond_to? :model and storage.model.class.respond_to? :after
        after << storage.model.class.after
      end
      if after.nil? or [] == after
        return response
      end
      if after.respond_to? :call
        after = [after]
      end

      after.select {|l|l.respond_to?(:call)}.each_with_index do |after_lambda, i|
        log.debug "After #{request.request_method} #{i+1}/#{after.size} (#{after_lambda})"
        response = after_lambda.call(request, response)
      end
      
      response
    end

    # Before request
    # @return request
    def before(request)

      before = config[:before]||[]
      if storage.respond_to? :model and storage.model.class.respond_to? :before
        before << storage.model.class.before
      end
      
      if before.nil? or [] == before
        return request
      end

      if before.respond_to? :call
        before = [before]
      end

      before.select{|l|l.respond_to?(:call)}.each_with_index do |before_lambda, i|
        log.debug "Before lambda #{i+1}/#{before.size} (#{before_lambda})"
        request = before_lambda.call(request)
      end
      request
      
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
        # @todo validation with schema if defined in service
        true
      end
    end

  end
  
  # Npolar::Api::Exception
  class Exception < ::Exception
  end

  end
end