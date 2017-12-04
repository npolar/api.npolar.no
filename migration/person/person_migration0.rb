# encoding: utf-8
require_relative "../../lib/person"

# $ ./bin/npolar-api-migrator http://localhost:9393/person ::PersonMigration0 --really=false > /dev/null

class PersonMigration0

  attr_accessor :log

  def model
    Person.new
  end
 
  def migrations
    [remove_title]
    #[opencms_to_api]
  end

  #def select
  #  lambda {|d| not d.schema? and d.fname? and d.lname? }
  #end
  
  def select
    #lambda {|d| d.title? }
  end
  
  
  def remove_title
      lambda {|d|
        if not d.first_name? 
          raise "No first name"
        end
        
        if d.title?
          d.delete :title
        end
        
        if not [true,false].include? d.currently_employed
          if d.currently_employed.is_a? String
            if d.currently_employed =~ /true/
              d.currently_employed = true
            end
          elsif d.currently_employed.nil? and d.events? and d.events.select {|e| e.type == 'quit'}.any?
            log.info d.id
            log.info d.events.to_json
            d.currently_employed = false
          end
          
        end
        
        if d.currently_employed? and not [true,false].include? d.currently_employed
          log.warn d.to_json
          raise d.currently_employed.to_json
        end
        
        if d.on_leave.nil?
          d.delete :on_leave
        end
        
        if d.on_leave? and not [true,false].include? d.on_leave
          d.on_leave = case d.on_leave
          when "false"
            false
          when "true"
            true
          else
            d.on_leave
          end
           
        end
        
        if d.on_leave? and not [true,false].include? d.on_leave
          raise d.to_json
        end
        
        d
      }
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

# magnus.hovind.rognhaug
#{"id":"bertran.kiil","first_name":"Bertran","last_name":"Kiil"}
#{"id":"fridjof.mehlum","first_name":"Fridjof","last_name":"Mehlum"}
#{"id":"reidun.yttergard.ingebrigtsen","first_name":"Reidun","last_name":"Yttergård Ingebrigtsen"}
#{"id":"vigdis.tverberg","first_name":"Vigdis","last_name":"Tverberg"}
#{"first_name":"Fridjof","last_name":"Mehlum"}
#{"first_name":"Ola","last_name":"Storrø"}
#{"first_name":"Carmen","last_name":"Vega"}
#{"first_name":"Kent-Jöran","last_name":"Johansson"}
#{"first_name":"Mats","last_name":"Björkman"}
#{"first_name":"Willy Hagen","last_name":"Larsen"}