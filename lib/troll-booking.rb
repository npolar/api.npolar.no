require "hashie"

class TrollBooking < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["troll-booking.json"] 
  end

end
