require "hashie"
require "date"
require "time"

module Lab

  # Parameter model
  class Ecotox < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator

    # @override MultiJsonSchemaValidator
    def schemas
      ["lab-ecotox.json"]
    end

  end

end
