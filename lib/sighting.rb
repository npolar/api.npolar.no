require "hashie"

class Sighting < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["sighting.json"] 
  end

end
