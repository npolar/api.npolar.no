require "hashie"

class SeaIceCore < Hashie::Mash
    include Npolar::Validation::MultiJsonSchemaValidator

    def schemas
        ["seaice-core.json"]
    end

end
