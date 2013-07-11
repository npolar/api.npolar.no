require "hashie"

# /service
# API endpoint service object
# @link http://data.npolar.no/schema/api
class Service < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

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