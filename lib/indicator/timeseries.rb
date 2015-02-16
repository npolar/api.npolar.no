# encoding: utf-8
require "hashie"
require "date"
require "time"

module Monitoring

  # [Timeseries](http://api.npolar.no/schema/monitoring-timeseries) model
  class Timeseries < Hashie::Mash

    #include Npolar::Validation::MultiJsonSchemaValidator
    
    # JSON_SCHEMA_URI = "http://api.npolar.no/schema/monitoring-timeseries"

    # JSON_SCHEMAS = ["monitoring-timeseries.json"]

    # @override MultiJsonSchemaValidator
    #def schemas
    #  JSON_SCHEMAS
    #end
    
  end
  
end
