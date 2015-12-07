require "hashie"

class MapArchive < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["map-archive-1.json"] 
  end

end