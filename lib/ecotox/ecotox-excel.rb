require "hashie"

class EcotoxExcel < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["ecotox-excel.json"] 
  end

end
