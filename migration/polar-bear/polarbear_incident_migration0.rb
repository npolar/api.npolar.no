# encoding: utf-8
# $ ./bin/npolar-api-migrator /polar-bear/incident PolarbearIncidentMigration0 --really=false > /dev/null

class PolarbearIncidentMigration0

  attr_accessor :log
  
  def model
    PolarbearIncident.new
  end
  
  def migrations
    [fix_by, remove_positions_and_source_from_root]
  end
  
  def fix_by
    lambda {|d|
      d.created_by = "unknown"
      d.updated_by = "unknown"
      d
    }
  end
  
  def remove_positions_and_source_from_root
    lambda {|d|
      if d.latitude?
        d.delete :latitude
      end
      
      if d.longitude?
        d.delete :longitude
      end
      
      if d.source?
        d.delete :source
      end
      
      log.info d.to_json
      
      d
    }
  end
end