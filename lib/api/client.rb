module Api
  class Client
    
    HOST = "api.npolar.no"
    SCHEME = "http"

    attr_accessor :collection, :host, :http, :workspace

    def initialize(config = {})
      
      @http = Patron::Session.new

      unless config["base_url"].nil?
        @http.base_url = config["base_url"]
      else
        @http.base_url = "{SCHEME}://{HOST}"
      end
    end

    def get(id, headers = {})
      response = @http.get(id, headers)
      [response.status, response.headers, response.body]
    end

    def delete(id, headers={})
      response = @http.delete(id, headers)
      [response.status, response.headers, response.body]
    end

    def head(id, headers={})
      response = @http.head(id, headers)
      [response.status, response.headers, []]
    end
    
    def options(id, headers={})
      response = @http.request("OPTIONS", id, headers)
      [response.status, response.headers, response.body]
    end

    def post(data, headers={})
      response = @http.post("", data, headers)
      [response.status, response.headers, response.body]
    end

    def put(id, data, headers={})
      response = @http.put(id, data, headers)
      [response.status, response.headers, response.body]
    end
    
    def trace(id, headers={})
      response = @http.trace(id, headers)
      [response.status, response.headers, response.body]
    end
    
  end
end