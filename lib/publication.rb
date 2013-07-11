require "hashie"

class Publication < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["publication.json"] 
  end

end