module Rack

  # Middleware for injecting GeoJSON into JSON documents
  class GeoJSON
    def point(lat, long)
      #unless lat.respond_to? :to_f
      #end
      { "type" => "Point",
        "coordinates" =>[long, lat]
      }
    end 
  end
end