require "hashie"
require "date"
require "time"

module Ecotox

class Excel < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["ecotox-excel.json"] 
  end

end
