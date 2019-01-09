require "hashie"
require "date"
require "time"

module Ecotox

  # Parameter model
  class Ecotox < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator

    # @override MultiJsonSchemaValidator
    def schemas
      ["ecotox.json"]
    end

  end

end
