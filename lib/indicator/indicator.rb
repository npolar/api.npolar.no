# encoding: utf-8
require "hashie"
require "date"
require "time"

module Indicator

  # Indicator model
  class Indicator < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator
    # @override MultiJsonSchemaValidator
    def schemas
      ["indicator-1.json"]
    end
    
  end
  
end