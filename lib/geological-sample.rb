require "hashie"

class GeologicalSample < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["geological-sample.json"] 
  end

end
