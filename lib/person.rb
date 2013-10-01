require "hashie"

class Person < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["person.json"] 
  end

end
