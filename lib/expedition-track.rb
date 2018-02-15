require "hashie"

class ExpeditionTrack < Hashie::Mash
	include Npolar::Validation::MultiJsonSchemaValidator
	
	def schemas
		[ "expedition_track.json" ]
	end
end
