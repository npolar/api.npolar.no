require "hashie"

class User < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["user-1.json"] 
  end

end