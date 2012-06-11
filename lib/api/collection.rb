module Api
  class Collection

    attr_accessor :validators, :formats, :format, :storage

    # http://stackoverflow.com/questions/5513558/executing-code-for-every-method-call-in-a-ruby-module
    FORMATS = ["json"]

    FORMAT = "json"

    def initialize(storage=nil)
      @storage = storage
      @formats = FORMATS
      @format = FORMAT
      @preprocessors = []
      @validators = []
      @postprocessors = []
    end

    def add_validator(validator)
      @validators << validator
    end

    def delete(id, headers = {})
      @response = @storage.delete(id, headers)
    end

    def get(id, headers = {})
      @response = @storage.get(id, headers)
    end

    def head(id, headers = {})
      @response = @storage.head(@id, @headers)
    end

    def options(id, headers = {})
      @response = @storage.options(id, headers)
    end

    def search
      @response = @storage.feed
    end

    def put(id, data, headers = {})
      @response = @storage.put(id, data, headers)
    end

    def post(data, headers = {})
      @response = @storage.post(data, headers)
    end

  end
end