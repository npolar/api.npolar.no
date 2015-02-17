# encoding: utf-8
require "hashie"
require "date"
require "time"

module Indicator

  # [Parameter](http://api.npolar.no/schema/indicator-parameter) model
  class Parameter < Hashie::Mash

    #include Npolar::Validation::MultiJsonSchemaValidator
    
    # JSON_SCHEMA_URI = "http://api.npolar.no/schema/indicator-parameter"

    # JSON_SCHEMAS = ["indicator-parameter.json"]

    # @override MultiJsonSchemaValidator
    #def schemas
    #  JSON_SCHEMAS
    #end
    
  end
  
end
