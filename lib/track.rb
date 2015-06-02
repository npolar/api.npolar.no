require "hashie"

class Track < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["track-1.json"] 
  end

end
