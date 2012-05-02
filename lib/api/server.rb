require "yajl/json_gem" # https://github.com/brianmario/yajl-ruby

module Api
  # Searchable RESTful storage: HTTP API for document collections
  # HTTP/1.1 http://www.ietf.org/rfc/rfc2616
  class Server

    attr_reader :collection

    attr_accessor :request, :response, :methods, :log

    # Default header
    HEADER = {
      "Content-Type"=> "application/json;charset=utf-8"
    }

    # Default known methods
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

    # Extract id
    # Id is extracted from first path parameter - or GET parameter "id"
    # GET parameter (?id=abc123) overrides path parameter (/abc123)
    def extract_id
      if @request.nil?
        return nil
      end
      
      if @request.GET["id"] != nil
        @request.GET["id"]
      else
        @request.path_info.split("/")[1]
      end
      
    end
    
    def initialize(app=nil)
      @app = app
      @methods = METHODS
    end
    
    def id
      if @id.nil?
        @id = extract_id
      end
      @id
    end

    # Rack application
    def call(env)
      dup._call(env)
    end

    # Rack application
    def _call(env)
      env["HTTP_COOKIE"] = ""
      @env = env
      @request = Rack::Request.new(env)
      @id = extract_id # If appropriate
      @response = Rack::Response.new([], 200, HEADER ) #(body=[], status=200, header={})
      
      handle(@request, @response)
    end

    def collection=collection
      if collection.respond_to? :put and collection.respond_to? :get
        @collection = collection
      else
        raise Api::Exception.new("Bad collection, missing #get and/or #put methods: #{collection.inspect}")
      end
    end
    
    # Search request is any Grequest with
    # - GET parameter "q"
    def search_request?
      if @request.path_info.split("/").size == 0
        return true
      end
      false
    end

    def document_request?
      true
    end

    # Handle HTTP request and return HTTP response triplet (Rack-style)
    def handle(request,response)

      # Check for collection gateway
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

      # Check if HTTP method is known
      unless known_method?
        return http_error(405)
      end

      # Good to go - everything before *must* return on error (or raise Exception)
      begin
        unless search_request?
          
          #if true
            
            headers = {}
            
            status, response_headers, body = case @request.request_method
              when "DELETE"  then @collection.delete(id, headers)
              when "GET"     then @collection.get(id, headers)
              when "HEAD"    then @collection.head(@id, headers)
              when "OPTIONS" then @collection.options(@id, headers)
              when "PATCH"   then @collection.patch(@id, request.body.read, headers)
              when "POST"    then @collection.post(request.body.read, headers)
              when "PUT"     then @collection.put(@id, request.body.read, headers)
              when "TRACE"   then @collection.trace(@id, headers)
            
            end

            
          #end
          
        else
          status, response_headers, body = @collection.search
        end
        
        @response.status = status
        @response.write(body)
        @response["Content-Type"] = response_headers["Content-Type"]
        @response.finish

      rescue      
        #server_error
      end

    end

    def known_method?
      methods.include? @request.request_method
    end

    def methods
      @methods
    end

    protected

    # true if collection can handle requested format
    # false if collection cannot handle requested format
    def acceptable?
      true
    end

    def authorized?
      true
    end
    
    def handle_document_request
      
      
    end

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
    
    def server_error
      http_error(500, self.inspect)
    end

  end
end
