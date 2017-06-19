require "hashie"

class WeatherRadiation < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["weather-radiation.json"] 
  end

end
