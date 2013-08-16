require "logger"

module Metadata
  class DatasetMigration0

    attr_writer :log
   
    def migrations
      [set_schema, contributors_with_roles, just_one_email,
        multiple_roles,locations_to_coverage_and_placenames, groups_to_topics,
        isoTopics, method_desc_to_comment, sensors_to_comment]
    end

    def log
      @log ||= Logger.new(STDERR)
    end

    def select
      lambda {|d| not d.schema? }
    end

    def set_schema
      [lambda {|d|
        !d.schema? },
      lambda {|d|
        d.schema = Service.factory("dataset-api.json").schema
        d
      }]
    end

    def multiple_roles
      [lambda {|d|
        d.contributors? },
      lambda {|d|
        names = d.contributors.map {|c| c.name }.uniq
        
        d.contributors = names.map {|name|
          entity = d.contributors.select {|c| c.name == name }.first

          uri = nil
          if name =~ /Norwegian Polar (Institute|Data)/
            uri = "http://npolar.no"
          end

          { "name" => name,
            "roles" => d.contributors.select {|c| c.name == name }.map {|c| c.role }.uniq,
            "email" => entity.email,
            "person" => entity.person == false ? false : true,
            "surname" => entity.surname,
            "uri" => uri
          }
        }
        d
      }]
    end


    def method_desc_to_comment
      [lambda {|d|
        d.method_desc? },
      lambda {|d|
        if !d.comment? or d.comment.nil?
          d.comment = ""
        end
        
        d.comment += "Method: #{d.method_desc}.\n"
        d.delete :method_desc
        d
      }]
    end

    def sensors_to_comment
      [lambda {|d|
        d.sensors? },
      lambda {|d|
        if !d.comment? or d.comment.nil?
          d.comment = ""
        end
        
        d.comment += "Sensors: #{d.sensors.join(", ")}.\n"
        d.delete :sensors
        d
      }]
    end

    # We don't want multiple emails
    def just_one_email
      [lambda {|d|
        d.contributors? and d.contributors.size > 0 },
      lambda {|d|
        d.contributors += d.contributors.select {|i|
          i.email? and i.email.is_a? Array
        }.map {
          |i|
            i.email = i.email.first
            i
          }
        d
      }]
    end

    # http://www.isotc211.org/2005/resources/Codelist/gmxCodelists.xml
    def isoTopics
      [lambda {|d|
        d.iso_topics? and d.iso_topics.size > 0 },
      lambda {|d|
        d.iso_topics = d.iso_topics.map {|i|
          case i
            when "imagery/base maps/earth cover"
              "imageryBaseMapsEarthCover"
            when "geoscientific information"
              "geoscientificInformation"
            when "climatology/meteorology/atmosphere"
              "climatologyMeteorologyAtmosphere"
            else i
          end
        }
        d
      }]
    end

    def groups_to_topics
      [lambda {|d|
        d.groups? and d.groups.size > 0 },
      lambda {|d|
        d.topics = d.groups
        d.delete :groups
        d.topics = d.topics.map {|t|
          case t
            when "sea_ice"
              "seaice"
            else t
          end

        }
        d
      }]
    end


    # Broken area names to real placenames, separated from spatial coverage
    #locations=[#<Metadata::Dataset area="dronning_maud_land" country_code="AQ" east=56.0 north=-70.0 south=-90.0 west=0.0>
    def locations_to_coverage_and_placenames
      [lambda {|d|
        d.locations? and d.locations.size > 0 },
      lambda {|d|
        d.coverage = d.locations.select {|l|
          l.north? and l.east? and l.south? and l.west?
        }.map {
          |l|
            { :north => l.north, :east => l.east, :south => l.south, :west => l.west }
        }
        d.placenames = d.locations.map {|l| l.area}.map {|area|
          case area
            when "dronning_maud_land"
              {"placename"=>"Dronning Maud Land", "country" => "AQ" }
            when "svalbard"
              {"placename"=>"Svalbard", "country" => "NO" }
            else {"placename"=>area}
          end
        }.select{|p|not p.nil? and not p["placename"] =~ /norway|arctic|antartic/ }.uniq
        d.delete :locations
        d
      }]
    end

    # roles from http://www.isotc211.org/2005/resources/Codelist/gmxCodelists.xml#CI_RoleCode
    def contributors_with_roles
      [lambda {|d|
        d.point_of_contact? or d.investigators? or d.contributors? or d.owners? },
      lambda {|d|
        
        if !d.contributors? or d.contributors.nil?
          d.contributors = []
        else
          d.contributors.map {|c|
            if false == c.role?
              c["role"]="originator"
            end

            c["name"] = c.first_name+" "+c.last_name
            c["surname"] = c.last_name
            c.delete :first_name
            c.delete :last_name

            c
          }
        end

        if d.investigators?
          d.contributors += d.investigators.map {|i|
            i["name"] = i.first_name+" "+i.last_name
            i["surname"] = i.last_name
            i.delete :first_name
            i.delete :last_name
            i["role"] = "principalInvestigator"
            i
          }
          d.delete :investigators
        end

        if d.point_of_contact?
            d.contributors += d.point_of_contact.map {|p|
              p.role = "pointOfContact"
              p.delete :org
              p
            }
            
            d.delete :point_of_contact
        end


        if d.owners?
          d.contributors += d.owners.map {|o|
            {
              "role" => "owner",
              "name" => o,
              "person" => false
            }
          }
          d.delete :owners
        end

        d
      }]
    end

    # groups=["glaciology", "topography"]
    # point_of_contact=[#<Metadata::Dataset email="jack.kohler@npolar.no" name="Geology and geophysics section" org="Norwegian Polar Institute">]
    # owners=["Norwegian Polar Institute"]
#"name":"Norwegian Polar Institute" / DATA centre => 


  end
end
