module Api
class Collection

  attr_accessor :validators

  def initialize(depot)
    @depot = depot
    @preprocessors = []
    @validators = []
    @postprocessors = []
  end

  def add_validator(validator)
    @validators << validator
  end

  def delete(id, headers = {})

    # Set id and headers so that these could be processed by #(before|after)_delete
    @id = id
    @headers = headers
    
    before_delete
    @response = @depot.delete(@id, @headers)
    after_delete
            
    @response
    
  end

  def get(id, headers = {})
    before_request("GET", id, headers)
    
    before_read
    @response = @depot.get(@id, @headers)
    after_read

    @response
  end

  def head(id, headers = {})
    before_request("HEAD", id, headers)
    
    before_read
    @response = @depot.head(@id, @headers)
    after_read
    
    @response
  end

  def options(id, headers = {})
    # Set id and headers so that these could be processed by #(before|after)_read
    @id = id
    @headers = headers
    
    before_read
    @response = @depot.options(@id, @headers)
    after_read
    
    @response
  end
  
  def search
    @depot.feed
  end

  def trace(id, headers = {})
    # Set id and headers so that these could be processed by #(before|after)_read
    @id = id
    @headers = headers
    
    before_read
    @response = @depot.trace(@id, @headers)
    after_read
    
    @response
  end


  def put(id, data, headers = {})
      
    # Set id, data and headers so that these could be processed by #(before|after)_save
    @id = id
    @data = data
    @headers = headers
    
    before_save 
    @response = @depot.put(@id, @data)
    after_save
    
    @response
  end
  
  def post(data, headers = {})
    raise "Not implemented"
  end


  protected

  def after_read
  end

  def after_save
  end

  def after_delete
  end

  def before_request(method, id, headers)
    # Set @id, @format and @headers so that these could be processed by #(before|after)_read
    @id, @format = id.split(".")
    @headers = headers
  end

  def before_read
      
  end
  
  def before_save
    # add timestamp
  end

  def before_delete
  end

  end
end