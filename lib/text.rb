require "hashie"

class Text < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["text-1.json"] 
  end

end
