require "hashie"

class EcotoxTemplate < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["ecotox-template.json"] 
  end

end
