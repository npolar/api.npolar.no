require "hashie"

class Placename < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["placename-1.json"]
  end

end