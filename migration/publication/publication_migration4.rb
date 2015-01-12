# encoding: utf-8

# $ ./bin/npolar-api-migrator /publication ::PublicationMigration4 --really=false > /dev/null
# In production: "2015-01-12"

class PublicationMigration4

  attr_accessor :log

  def migrations
    [dmitry_divine]
  end
  
  def model
    Publication.new
  end
    
  def dmitry_divine
    lambda {|d|
      if idx = (d.people||[]).index {|p| p.email =~ /dimitry[.]divine[@]/}
        
        d.people[idx] = d.people[idx].merge ({ id: "dmitry.divine", email: "dmitry.divine@npolar.no", first_name: "Dmitry", last_name: "Divine" })
        log.info d.people[idx].to_json 
      end
      d
    }
  end

end