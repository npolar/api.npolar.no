require "hashie"
module Npolar
  module Validation
    class GenericJsonValidator < Hashie::Mash
      include MultiJsonSchemaValidator
    end
  end
end