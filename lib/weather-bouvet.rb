require "hashie"

class WeatherBouvet < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["weather-bouvet.json"] 
  end

  def before_valid
  end
end
