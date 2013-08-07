require "hashie"

# /service API
# @link http://data.npolar.no/schema/api
class Service < Hashie::Mash
  
  include Npolar::Validation::MultiJsonSchemaValidator


  def self.after_lambda
    lambda {|request, response|
      if ["POST","PUT"].include? request.request_method
        
        service = self.new(JSON.parse(request.body.read))
        bootstrap = Npolar::Api::Bootstrap.new
        bootstrap.log = Npolar::Api.log
        bootstrap.create_database(service)

      end
      response
    }
  end

  def self.factory(seedfile)
    seedfile = File.absolute_path(File.join(File.dirname(__FILE__), "..", "seed", "service", seedfile))
    unless File.exists?(seedfile)
      raise "Seedfile #{seedfile} does not exist"
    end
    self.new(JSON.parse(File.read(seedfile)))
  end

  def schemas
    ["api.json"] 
  end

  def to_s
    to_json
  end

end