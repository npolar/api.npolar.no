require "hashie"

class PolarbearIncident < Hashie::Mash
	include Npolar::Validation::MultiJsonSchemaValidator
	
	def schemas
		[ "polarbear-incident-test.json" ]
	end
end
