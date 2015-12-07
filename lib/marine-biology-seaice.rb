require "hashie"

class MarineBiologySeaice < Hashie::Mash
	include Npolar::Validation::MultiJsonSchemaValidator
	
	def schemas
		[ "marine-biology-seaice.json" ]
	end
end
