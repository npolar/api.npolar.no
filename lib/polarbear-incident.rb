require "hashie"

class PolarbearIncident < Hashie::Mash
	include Npolar::Validation::MultiJsonSchemaValidator
	
	def schemas
		[ "polarbear-incident-1.1.0.json" ]
	end
end
