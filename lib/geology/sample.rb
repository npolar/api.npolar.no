# encoding: utf-8
require "hashie"
require "date"
require "time"

module Geology

  # Parameter model
  class Sample < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator

    # @override MultiJsonSchemaValidator
    def schemas
      ["geology-sample.json"]
    end

  end

end
