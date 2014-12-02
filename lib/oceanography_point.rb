require "hashie"

class OceanographyPoint < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["oceanography_point.json"]
  end

end
