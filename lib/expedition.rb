require "hashie"

class Expedition < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["http://api.npolar.no/schema/expedition-1"]
  end

end
