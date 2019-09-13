require "hashie"
require "date"
require "time"

module Lab

  # Parameter model
  class Biomarker < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator

    # @override MultiJsonSchemaValidator
    def schemas
      ["lab-biomarker.json"]
    end

  end

end
