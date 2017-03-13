require "hashie"

class RockCollection < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["rock-collection.json"] 
  end

end
