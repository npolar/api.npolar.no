require "hashie"

class Publication < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["publication-1.json"] 
  end

end