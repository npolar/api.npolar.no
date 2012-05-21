module Api
  class Collection

    attr_accessor :validators, :formats, :format

    # http://stackoverflow.com/questions/5513558/executing-code-for-every-method-call-in-a-ruby-module
    FORMATS = ["json"]

    FORMAT = "json"

    def initialize(depot)
      @depot = depot
      @formats = FORMATS
      @preprocessors = []
      @validators = []
      @postprocessors = []
    end

    def add_validator(validator)
      @validators << validator
    end

    def delete(id, headers = {})
      @response = @depot.delete(id, headers)
    end

    def get(id, headers = {})
      before_request("GET", id, headers)
      @response = @depot.get(@id, @headers)
    end

    def head(id, headers = {})
      before_request("HEAD", id, headers)
      @response = @depot.head(@id, @headers)
    end

    def options(id, headers = {})
      @response = @depot.options(id, headers)
    end

    def search
      @response = @depot.feed
    end

    def put(id, data, headers = {})
      @response = @depot.put(id, data, headers)
    end

    def post(data, headers = {})
      @response = @depot.post(data, headers)
    end

    protected

    def before_request(method, id, headers)
      # Set @id, @format and @headers
      @id, @format = id, FORMAT
      if id =~ /[.]/
        @id, @format = id.split(".") unless id == ""
      end
      #if @id is a uuid => delete "-"
      @headers = headers
    end

  end
end