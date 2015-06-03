# encoding: utf-8
require "hashie"
require "date"
require "time"

module Indicator

  # Parameter model
  class Parameter < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator
    
    # @override MultiJsonSchemaValidator
    def schemas
      ["indicator-parameter-1.json"]
    end
    
  end
  
end
