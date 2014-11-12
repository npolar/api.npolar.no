require "hashie"

class Publication < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["course.json"] 
  end

end
