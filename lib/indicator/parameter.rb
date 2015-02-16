# encoding: utf-8
require "hashie"
require "date"
require "time"

module Monitoring

  # [Parameter](http://api.npolar.no/schema/monitoring-parameter) model
  class Parameter < Hashie::Mash

    #include Npolar::Validation::MultiJsonSchemaValidator
    
    # JSON_SCHEMA_URI = "http://api.npolar.no/schema/monitoring-parameter"

    # JSON_SCHEMAS = ["monitoring-parameter.json"]

    # @override MultiJsonSchemaValidator
    #def schemas
    #  JSON_SCHEMAS
    #end
    
  end
  
end
