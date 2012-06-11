require "yajl/json_gem" # https://github.com/brianmario/yajl-ruby
require "rack/utils"

# docs => http://docs.api.syllabs.com/index.html
module Api
  # API Server
  #
  # Rack http://rack.rubyforge.org/doc/SPEC.html
  # HTTP/1.1 http://tools.ieetf.org/html/rfc2616 | http://www.w3.org/Protocols/rfc2616/rfc2616.html
  class Server < Api::Rack::Middleware

    attr_reader :collection, :default_header
    
    FORMAT = "json"

    JSON_HEADER = {
      "Content-Type" => "application/json; charset=utf-8"
    }
    METHODS = ["DELETE", "GET", "HEAD", "POST", "PUT"]

    
    # Extract id from request
    def id(request)
      id = request.path_info.split("/")[1]
      
      if id =~ /[.]/
        id = id.split(".")[0]
      end
      
      id
    end

    # Extract format from request / collection
    def format(request)
      if request.params["format"]
        format = request.params["format"]
      elsif request.path_info =~ /[.]/
        format = path_format request
      elsif collection.respond_to? :formats and collection.formats.include? accept_format(request)
        format = accept_format(request) 
      elsif collection.respond_to? :default_format
        collection.default_format
      else
        format = FORMAT
      end
      format
    end

    def initialize(app=nil)
      @app = app
      @methods = METHODS
      @default_header = JSON_HEADER
      
    end

    # Rack application
    def call(env)
      env["HTTP_COOKIE"] = ""
      request = ::Rack::Request.new(env)
      handle(request)
    end

    # Collection setter
    def collection=collection
      if collection.respond_to? :get
        @collection = collection
      else
        raise Api::Exception.new("Bad collection, missing #get #{collection.inspect}")
      end
    end

    # Search request is a GET request with GET parameter "q"
    def search_request? request
      if !request_id?(request) && request.request_method == "GET"
        return true
      end
      false
    end

    def request_id? request
      if id(request).nil? or id(request).size == 0
        return false
      end
      true
    end


    # Handle HTTP request and return HTTP response triplet (Rack-style)
    def handle(request)

      @request=request

      # Collection gateway set?
      if collection.nil?
        return http_error(503, "No collection set")
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
        return http_error(405, "The following HTTP methods are allowed: #{http_methods.join(", ")}")
      end

      # 414 Request-URI Too Long

      begin

        headers = ::Rack::Utils::HeaderHash.new(request.env)
        body = request.body.read # request.body is now empty
        format = format(request)
        collection.format = format

        if ["PUT", "POST"].include? request.request_method
          
          if 0 == body.bytesize
            return http_error(400, "#{request.request_method} with no body")
          end

#          unless accepts? format
#            return http_error(415, "Collection does not accept documents in '#{format(request)}' format.
#Acceptable formats are: #{collection.formats.join(", ")}")
#          end
#
#          # check for [{},{}]
#
#        else
#
#          unless acceptable_format? request
#            return http_error(406, "Unacceptable format '#{format(request)}'.
#Acceptable formats are: #{collection.formats.join(",")}")
#          end 
        end

        unless search_request?(request)

          id = id(request)

          # POST is the only method where id can be blank
          unless "POST" == request.request_method
            if id.nil? or id.empty? or id =~ /\s+/
              return http_error(400, "Missing id, cannot #{request.request_method}")
            end
          end

          response_status, response_headers, response_body = case request.request_method
            when "DELETE"  then collection.delete(id, headers)
            when "GET"     then collection.get(id, headers)
            when "HEAD"    then collection.head(id, headers)
            when "POST"    then collection.post(body, headers)
            when "PUT"     then collection.put(id, body, headers)
          end

          #if 404 == response_status
          #  return http_error(404, "Resource does not exist")
          #end

        else

          response_status, response_headers, response_body = collection.search

        end

        response = ::Rack::Response.new([], response_status, default_header ) #(body=[], status=200, header={})
        
        # Force Content-Type
        if response_headers["Content-Type"].nil?
          response["Content-Type"] = content_type(request)
        else
          response["Content-Type"] = response_headers["Content-Type"]
        end

        # Force UTF-8
        if response["Content-Type"] !~ /; charset=/
          response["Content-Type"] +=  "; charset=utf-8"
        end

        # Recalculate Content-Length (except on HEAD)
        unless request.request_method =~ /HEAD/         
          # We don't recalculate content length on HEAD, that would always give 0 (and it should report length of a GET). 
          response["Content-Length"] = response_body.respond_to?(:bytesize) ? response_body.bytesize.to_s : response_body.size.to_s
        end

        # Write body
        unless request.request_method =~ /HEAD/    
          response_body = response_body.to_json if response_body.is_a? Hash
          # DELETE has body it failed
          unless request.request_method == "DELETE"   
            response.write(response_body)
          end
        else

        end

        response

      rescue => e
        puts e.message
        puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        http_error(500, "Polar bears ate your request")
      ensure
        # log critical error
      end

    end

    def accepts? format
      collection.accepts? format
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
      #return true if format(request) =~ /^(.*)?$/
      collection.formats.include? format(request)
    end

    def authorized?
      true
    end

    protected  

    def path_format request
      return nil if request.path_info.nil? or request.path_info !~ /[.]/
      format = request.path_info.split(".")[1]
      if format =~ /[\w+\/]/
        format = format.split("/")[0]
      end
      format
    end

    # Stupid, but we only care about the first accept header format
    def accept_format request

      return nil if request.env['HTTP_ACCEPT'].nil?

      format = request.env['HTTP_ACCEPT'].scan(/[^;,\s]*\/[^;,\s]*/)[0].split("/")[1]
      if format =~ /[+]/
        format = format.split("+")[0]
      end
      format
    end

    # Stupid, but intended for fallback Content-Type (when response does not contain any)
    def content_type request
      "application/#{format(request)}" 
    end

    def default_header=str
      @default_header = str
    end

    def http_error(status, explanation=nil)
      
      error = error_hash(status, explanation).to_json+"\n"

      unless @request.nil?
        if "HEAD" == @request.request_method or 204 == status
          error = []
        end
      end

      ::Rack::Response.new(error, status, JSON_HEADER)
    end

  end
end
