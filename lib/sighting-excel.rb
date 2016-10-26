require "hashie"

class SightingExcel < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["sighting-excel.json"] 
  end

end
