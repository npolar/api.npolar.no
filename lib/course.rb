require "hashie"

class Course < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["course.json"] 
  end

end
