# encoding: utf-8
require "hashie"
require "date"
require "time"

module Indicator

  # [Indicator](http://api.npolar.no/schema/indicator) model
  class Indicator < Hashie::Mash

    #include Npolar::Validation::MultiJsonSchemaValidator
    
    # JSON_SCHEMA_URI = "http://api.npolar.no/schema/indicator"

    # JSON_SCHEMAS = ["indicator-indicator.json"]

    # @override MultiJsonSchemaValidator
    #def schemas
    #  JSON_SCHEMAS
    #end
    
  end
  
end
