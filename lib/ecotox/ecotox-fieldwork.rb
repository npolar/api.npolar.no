require "hashie"
require "date"
require "time"

module Ecotox

  # Parameter model
  class Fieldwork < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator

    # @override MultiJsonSchemaValidator
    def schemas
      ["ecotox-fieldwork.json"]
    end

  end

end
