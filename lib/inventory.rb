require "hashie"

class Inventory < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["inventory.json"] 
  end

end
