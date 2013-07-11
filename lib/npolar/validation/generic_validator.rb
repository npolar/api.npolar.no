require "hashie"
module Npolar
  module Validation
    class GenericValidator < Hashie::Mash
      attr_writer :schemas
      include MultiJsonSchemaValidator
    end
  end
end