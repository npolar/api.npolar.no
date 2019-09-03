require "hashie"
require "date"
require "time"

module Lab

  # Parameter model
  class StableIsotope < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator

    # @override MultiJsonSchemaValidator
    def schemas
      ["lab-stable-isotope.json"]
    end

  end

end
