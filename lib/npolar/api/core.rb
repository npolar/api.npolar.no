module Npolar
  module Api
  # Npolar::Api::Core
  #
  # Rack class to create REST-style HTTP APIs
  # @link https://github.com/npolar/api.npolar.no/wiki/Core
  # @link Rack http://rack.rubyforge.org/doc/SPEC.html
  # @link HTTP/1.1 http://tools.ieetf.org/html/rfc2616 | http://www.w3.org/Protocols/rfc2616/rfc2616.html
  class Core < Rack::Middleware

    extend Forwardable # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/forwardable/rdoc/Forwardable.html

    # Default configuration
    CONFIG = {
      :accepts => lambda { |storage| storage.respond_to?(:accepts) ? storage.accepts : [] }, # Accepted formats (incoming)
      :formats => lambda { |storage| storage.respond_to?(:formats) ? storage.formats : [] }, # Supported formats (outgoing)
      :storage => nil,
      :methods => ["DELETE", "GET", "HEAD", "POST", "PUT"], # Allowed HTTP methods
      :headers => [],
    }

    attr_accessor :auth, :log

    # Delegate HTTP methods handlers to storage
    def_delegators :storage, :delete, :get, :head, :post, :put

    # Rack application
    # @param env
    # @return [status, headers, body#each]
    def call(env)
      begin
        env["HTTP_COOKIE"] = ""
        @request = Rack::Request.new(env) # <Npolar::Rack::Request>
        handle(request)
      rescue => e
        puts "="*80+"\n"+e.class.name+"\n"+e.message
        puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        http_error(503, "Polar bears ate your request")
      ensure
        # log error
      end
    end

    # Handle HTTP request and return HTTP response triplet (Rack-style)
    # @return [status, headers, body#each]
    def handle(request)

      if storage.nil?
        return http_error(501, "No storage set for API endpoint, cannot handle request")
      end

      unless method_allowed? request_method
        return http_error(405, "The following HTTP methods are allowed: #{methods.join(", ")}")
      end

      headers = ::Rack::Utils::HeaderHash.new(request.env)

      if ["GET", "HEAD"].include? request_method # "DELETE" *not* included, deleting means removing all formats!
        unless acceptable? format
          return http_error(406, "Unacceptable format '#{format}', this API endpoint supports the following #{request_method} formats: #{formats.join(",")}")
        end
      elsif ["PUT", "POST"].include? request_method
        
        # Insist on Content-Length on chunked transfers
        # if headers["Content-Length"].nil? or headers["Content-Length"].to_i <= 0
        #  return http_error(411)
        # end

        unless accepts? request.media_format
          return http_error(415, "This API endpoint does not accept documents in '#{request.media_format}' format, acceptable #{request_method} formats are: '#{accepts.join(", ")}'")
        end

        document = request.body.read # request.body is now empty

        if 0 == document.bytesize or document =~ /^\s+$/
          return http_error(412, "#{request_method} document with no body")
        end
        
        #422  => 'Unprocessable Entity'?
        if storage.respond_to? :parsable?
          if false == storage.parsable? #
            return http_error(422, "#{request_method} document with no body")
          end

        end
      end

      # GET, HEAD and POST are the only method where id can be blank
      unless /(GET|HEAD|POST)/ =~ request_method
        unless id?
          return http_error(412, "Missing or blank request id, cannot handle #{request_method} request")
        end
      end

      status, headers, body = case request_method
        when "DELETE"  then delete(id, params)
        when "GET"     then get(id, params)
        when "HEAD"    then head(id, params)
        when "POST"    then post(document, params)
        when "PUT"     then put(id, document, params)
      end

      if body.respond_to? :body and body.body.respond_to? :force_encoding
        body = body.body.force_encoding('UTF-8')
      end
  
      Rack::Response.new(body, status, headers)

    end

    def storage
      config[:storage] or raise Exception, "No storage"
    end

    def storage=storage
      #case storage
      #  when Storage::Couch then config[:storage]=storage
      #  else storage = Storage::Couch.new(storage)
      #end
      #  when Storage::Couch then
      config[:storage]=storage

    end

    protected

    # @return Boolean
    #   true if endpoint can deliver requested format
    #   false if endpoint cannot handle requested format
    def acceptable? format
      formats.include? format
    end

    # @return Boolean
    #   true if endpoint can receive requested format
    #   false if collection cannot receive requested formar
    def accepts? format
      accepts.include? format
    end

    def accepts
      case config[:accepts]
        when String then [config[:accepts]]
        when Array then config[:accepts]
        when Proc then config[:accepts].call(storage)
      end
    end
    
    def format
      request.format.empty? ? config[:formats].first : request.format
    end

    def formats
      case config[:formats]
        when String then [config[:formats]]
        when Proc then config[:formats].call(storage)
        when Array then config[:formats]
        else []
      end
    end

    def methods
      case config[:methods]
        when String then [config[:methods]]
        when Proc then config[:methods].call(request)
        when Array then config[:methods]
        else []
      end
    end

    def method_allowed? method
      methods.include? method
    end

  end

  class Exception < Exception
  end

  end
end
