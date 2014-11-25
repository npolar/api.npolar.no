# encoding: utf-8
require "hashie"
require "date"
require "time"

module Monitoring

  # [Indicator](http://api.npolar.no/schema/monitoring-indicator) model
  class Indicator < Hashie::Mash

    #include Npolar::Validation::MultiJsonSchemaValidator
    
    # JSON_SCHEMA_URI = "http://api.npolar.no/schema/monitoring-indicator"

    # JSON_SCHEMAS = ["monitoring-indicator.json"]

    # @override MultiJsonSchemaValidator
    #def schemas
    #  JSON_SCHEMAS
    #end
    
  end
  
end
