# encoding: utf-8
require "hashie"
require "date"
require "time"

module Indicator

  # [Timeseries](http://api.npolar.no/schema/indicator-timeseries) model
  class Timeseries < Hashie::Mash

    #include Npolar::Validation::MultiJsonSchemaValidator
    
    # JSON_SCHEMA_URI = "http://api.npolar.no/schema/indicator-timeseries"

    # JSON_SCHEMAS = ["indicator-timeseries.json"]

    # @override MultiJsonSchemaValidator
    #def schemas
    #  JSON_SCHEMAS
    #end
    
  end
  
end
