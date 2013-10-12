# encoding: utf-8
require_relative "../../lib/person"

# $ ./bin/npolar_api_migrator http://localhost:9393/person ::PersonMigration0 --really=false > /dev/null

class PersonMigration0

  attr_accessor :log

  def model
    Person.new
  end
 
  def migrations
    [opencms_to_api]
  end

  def select
    lambda {|d| not d.schema? and d.fname? and d.lname? }
  end

  def opencms_to_api
      lambda {|d|

        d = d.merge({ schema: "http://api.npolar.no/schema/person",
          organisation: "npolar.no",
          collection: "person",
          first_name: d.fname,
          last_name: d.lname,
          title: d.fname+" "+d.lname,
          jobtitle: d.position,
          orgtree: d.org_units.map {|u| u.unit },
      
          links: [
            { href: "https://api.npolar.no/person/#{d.id}.json", rel: "edit", type: "application/json" },
            { href: "http://npolar.no/en/people/#{d.id}/", rel: "profile", hreflang: "en", type: "text/html" },
            { href: "http://npolar.no/no/ansatte/#{d.id}/", rel: "profile", hreflang: "no", type: "text/html" }
          ]
        })
        if d.image?
          d.links << { href: d.image, rel: "profile-image", type: "image/jpeg" }
        end
        
        [:fname, :lname, :org_units, :image, :employment, :position].each do |k|
          d.delete k
        end

        d
      }
  end

end