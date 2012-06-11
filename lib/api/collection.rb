module Api

  # http://stackoverflow.com/questions/5513558/executing-code-for-every-method-call-in-a-ruby-module
# status if >= 400 rewrite response to standard format
  class Collection

    attr_accessor :validators, :formats, :format, :storage, :accepts, :response

    ACCEPTS = ["json"]

    FORMATS = ["json"]

    FORMAT = "json"

    def initialize(storage=nil)
      @storage = storage
      @accepts = ACCEPTS
      @formats = FORMATS
      @format = FORMAT
      @preprocessors = []
      @validators = []
      @postprocessors = []
    end

    def add_validator(validator)
      validators << validator
    end

    def delete(id, headers = {})
      # Never EVER delete without an id
      if id.nil? or id.empty? or id =~ /\s+/
        raise "Cannot delete a resource when id is blank"
      end
      response = storage.delete(id, headers)
    end

    def get(id, headers = {})
      response = storage.get(id, headers)
    end

    def head(id, headers = {})
      response = storage.head(id, headers)
    end

    def search
      response = storage.feed
    end

    def post(data, headers = {})
      response = storage.post(data, headers)
    end

    def put(id, data, headers = {})
      # Never EVER put without an id
      if id.nil? or id.empty? or id =~ /\s+/
        raise "Cannot put data when id is blank"
      end
      response = storage.put(id, data, headers)
    end


  end
end