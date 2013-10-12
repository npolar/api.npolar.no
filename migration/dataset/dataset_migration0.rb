require "logger"

module Metadata

# Migrates 12 datasets in production before dataset schema 1.0 was finalised
# $ ./bin/npolar_api_migrator http://api:9393/dataset ::Metadata::DatasetMigration0 --really=false > /dev/null

  class DatasetMigration0

    IDS = ["59102277-1e3d-42af-97de-fc2f49e2f203",
    "5a845750-e924-11e2-b06b-005056ad0004",
    "67eede8a-fe8f-11e2-ba11-005056ad0004",
    "89f430f8-862f-11e2-8036-005056ad0004",
    "8c1d466e-8aec-11e2-bc03-005056ad0004",
    "9fd6dae0-863b-11e2-8036-005056ad0004",
    "ad6c4c5a-e926-11e2-b06b-005056ad0004",
    "bc460306-87e7-11e2-8c07-005056ad0004",
    "d756f766-de33-11e2-8993-005056ad0004",
    "f1fc782a-fa7b-11e2-bd10-005056ad0004",
    "fc83ae54-8658-11e2-8f45-005056ad0004",
    "fff1ccc2-fa7c-11e2-bd10-005056ad0004"]

    attr_accessor :log
   
    def migrations
      [ set_schema,
        fix_licence_uris,
        investigators_are_primaryInvestigators,
        contributors_are_processors,
        owners_are_organisations,
        remove_point_of_contact,
        just_one_email,
        locations_to_coverage_and_placenames,
        groups_to_topics,
        isoTopics,
        method_desc_to_comment,
        sensors_to_comment,
        gcmd_block,
        edits_and_timestamps,
        owners_are_ksat_and_nsc]
    end

    def model
      Metadata::Dataset.new
    end

    def select
      lambda {|d| not d.schema? and IDS.include? d.id }
    end

    def fix_licence_uris
      [lambda {|d|
        d.licences? },
      lambda {|d|
        d.licences = d.licences.map {|l|
          case l
            when "http://creativecommons.org/licences/by/3.0/no/"
              "http://creativecommons.org/licenses/by/3.0/no/"
            else l
          end
        }
        d
      }]
    end

    def set_schema
      [lambda {|d|
        not d.schema? },
      lambda {|d|
        d.schema = Metadata::Dataset.schema_uri
        d
      }]
    end

    def investigators_are_primaryInvestigators
      [lambda {|d|
        d.investigators? },
      lambda {|d|
        d.people = d.investigators.map {|i|
          { first_name: i.first_name,
            last_name: i.last_name,
            roles: ["principalInvestigator"],
            email: i.email
          }          
        }
        d.delete :investigators
        d
      }]
    end

    def contributors_are_processors
      [lambda {|d|
        d.contributors? },
      lambda {|d|
        d.people = d.contributors.map {|c|
          { first_name: c.first_name,
            last_name: c.last_name,
            roles: ["processor"],
            email: c.email
          }          
        }
        d.delete :contributors
        d
      }]
    end

    def owners_are_organisations
      [lambda {|d|
        d.owners?},
      lambda {|d|
        d.organisations = d.owners.map {|o|
          { name: o,
            roles: ["owner"]
          }          
        }
        d.delete :owners
        d
      }]
    end

    def remove_point_of_contact
      [lambda {|d|
        d.point_of_contact?},
      lambda {|d|
        d.delete :point_of_contact
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

    def just_one_email
      [lambda {|d|
        d.people? },
      lambda {|d|
        d.people += d.people.select {|p|
          p.email? and p.email.is_a? Array
        }.map {
          |p|
            p.email = p.email.first
            p
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
        d.topics = d.topics.reject {|t|t == "geophysics"}.map {|t|
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

    def gcmd_block
      [lambda {|d|
        d.science_keywords? },
      lambda {|d|
        d.gcmd = { "sciencekeywords" => d.science_keywords }
        d.delete :science_keywords
        d
      }]
    end

    def edits_and_timestamps
      [lambda {|d|
        true },
      lambda {|d|

        edits = d.editors? ? d.editors : []
        d.edits = edits 
        d.delete :editors

        d.created = d.published
        d.delete :published
        d
      }]
    end

    def owners_are_ksat_and_nsc
      [lambda {|d|
        d.id == "59102277-1e3d-42af-97de-fc2f49e2f203" },
      lambda {|d|
        d.organisations.select {|o| o.id = "npolar.no"}[0].roles = ["publisher", "pointOfContact"]
        d.organisations << {id: "ksat.no", roles: ["owner"], name: "Kongsberg Satellite Services", gcmd_short_name: "KSAT" }
        d.organisations << {id: "spacecentre.no", roles: ["owner"], name: "The Norwegian Space Centre" }
        d
        
      }]
    end

  end
end
