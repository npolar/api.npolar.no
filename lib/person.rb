require "hashie"

class Person < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["person-1.json"] 
  end

end
