require "hashie"

class Statistic < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["statistic.json"] 
  end

end
