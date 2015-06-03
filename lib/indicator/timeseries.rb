# encoding: utf-8
require "hashie"
require "date"
require "time"

module Indicator

  # Indicator timeseries model
  class Timeseries < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator
    # @override MultiJsonSchemaValidator
    def schemas
      ["indicator-timeseries-1.json"]
    end
    
  end
  
end