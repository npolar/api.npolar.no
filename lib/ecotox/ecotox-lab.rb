require "hashie"
require "date"
require "time"

module Ecotox

  # Parameter model
  class Lab < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator

    # @override MultiJsonSchemaValidator
    def schemas
      ["ecotox-lab.json"]
    end

  end

end
