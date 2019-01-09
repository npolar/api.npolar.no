require "hashie"
require "date"
require "time"

module Ecotox

  # Parameter model
  class Template < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator

    # @override MultiJsonSchemaValidator
    def schemas
      ["ecotox-template.json"]
    end

  end

end
