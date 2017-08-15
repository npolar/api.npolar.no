require "hashie"

class IceCore < Hashie::Mash
    include Npolar::Validation::MultiJsonSchemaValidator

    def schemas
        ["ice-core-schema.json"]
    end

end
