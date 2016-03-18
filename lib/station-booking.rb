require "hashie"

class StationBooking < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["station-booking.json"] 
  end

end
