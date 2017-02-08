require "hashie"

class SeabirdColony < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["seabird-colony.json"] 
  end

end
