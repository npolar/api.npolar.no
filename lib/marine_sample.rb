require "hashie"

class MarineSample < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["marine_sample.json"]
  end

end
