require "hashie"

class RadiationWeather < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["radiation-weather.json"] 
  end

end
