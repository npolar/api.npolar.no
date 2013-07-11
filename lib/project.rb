require "hashie"

class Project < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["project.json"] 
  end

end