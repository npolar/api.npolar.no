# encoding: utf-8

# Migrates
# $ ./bin/npolar-api-migrator /biology/marine/sample/ MarineBiologySampleMigration0 --really=false > /dev/null

class MarineBiologySampleMigration0

  attr_accessor :log

  def model
    Marine::Samples.new
  end
 
  def migrations
    [remove_end_dec_min_from_latitude_longitude, latitude_longitude, simplify]
  end

  # Remove 10 (!) redundant position fields
  def remove_end_dec_min_from_latitude_longitude
    lambda {|d|
      if d.latitude_start_dec?
        d.latitude_start = d.latitude_start_dec
        #log.info d.latitude_start
        d.delete :latitude_start_dec
      end
      
      if d.longitude_start_dec?

        d.longitude_start=d.longitude_start_dec
        #log.info d.longitude_start
        d.delete :longitude_start_dec
        
      end
      
      d.delete :latitude_end
      d.delete :longitude_end
      
      d.delete :latitude_end_dec
      d.delete :longitude_end_dec
      
      
      d.delete :latitude_start_min
      d.delete :longitude_start_min
      
      d.delete :latitude_end_min
      d.delete :longitude_end_min
      d
    }
  end
  
  # Use just latitude/longitude (no _start)
  def latitude_longitude
    lambda {|d|
      if d.latitude_start?
        d.latitude = d.latitude_start
        d.delete :latitude_start
      end
      
      if d.longitude_start?
        d.longitude = d.longitude_start
        d.delete :longitude_start
      end
      log.info "#{d.latitude} #{d.longitude}"
      d
    }
  end
  
  def simplify
     lambda {|d|
      if d.conveyance == "LANCE"
         d.conveyance = "Lance"
      end
      d.delete :status
      d.delete :flowmeter_start
      d.delete :flowmeter_stop
      d.delete :filteredwater
      d
     }
  end


end