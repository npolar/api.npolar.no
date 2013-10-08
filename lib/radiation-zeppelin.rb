require "hashie"

class RadiationZeppelin < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["radiation-zeppelin.json"] 
  end

  def before_valid
  end
end
