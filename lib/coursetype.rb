require "hashie"

class Coursetype < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["coursetype.json"] 
  end

end
