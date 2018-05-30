require "hashie"

class Ecotox < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["ecotox.json"] 
  end

end
