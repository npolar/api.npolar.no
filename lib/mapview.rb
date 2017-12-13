require "hashie"

class Mapview < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["http://api.npolar.no/schema/mapview"]
  end

end
