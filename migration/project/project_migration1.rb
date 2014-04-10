# encoding: utf-8

# $ ./bin/npolar-api-migrator https://api.npolar.no/project ::ProjectMigration1 --really=false > /dev/null
# In production: "2014-04-10T09:09:35Z" http://api.npolar.no/editlog/238f44ea-52c8-4b67-936e-e503a1ca4e8a

class ProjectMigration1

  attr_accessor :log

  def migrations
    [geir_wing_gabrielsen]
  end
  
  def model
    Project.new
  end
  
  def geir_wing_gabrielsen
    lambda {|d|
      if idx = d.people.index {|p| p.email =~ /geir[.]gabrielsen[@]/}
        
        d.people[idx] = d.people[idx].merge ({ email: "geir.wing.gabrielsen@npolar.no", first_name: "Geir Wing" })
        log.info d.people[idx].to_json 
      end
      d
    }
  end

end