require "hashie"

class User < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["user.json"] 
  end

end