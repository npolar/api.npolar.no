require "logger"
require_relative "../../lib/metadata/dataset"

module Metadata

  # $ ./bin/npolar_api_migrator http://api:9393/dataset Metadata::DatasetMigration2 --really=false > /dev/null

  class DatasetMigration2

    attr_accessor :log
   
    def migrations
      [ all_principalInvestigators_are_authors,
        all_owners_are_authors,
        data_link_from_dataset_link,
        set_organisation_from_email,
        owners_are_ksat_and_nsc]
    end

    def model
      Metadata::Dataset.new
    end

    def all_principalInvestigators_are_authors
      lambda {|d|
        
        d.people.select {|p|

          p.roles.include?("principalInvestigator") and not p.roles.include?("author")}.each do |person|
          person.roles << "author"
          #log.info "#{d.id}.people = #{d.people.to_json}"
        end
        d
      }
    end

    def all_owners_are_authors
      lambda {|d|

        d.organisations.select {|o| o.roles? and o.roles.include?("owner") and not o.roles.include?("author") }.each do |organisation|

          organisation.roles << "author"

        end
        d
      }
    end

    def data_link_from_dataset_link
      lambda {|d|

        d.links.select {|link| link.rel == "dataset" }.each do |link|
          
          link.rel = "data"
        end
        d
      }

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

    def set_organisation_from_email
      lambda {|d|

        d.people.select {|p| p.organisation.nil?}.each do |p|
          if p.email =~ /@/ and p.email !~ /gmail[.]com$/
            p.organisation = p.email.split("@")[1] 
            log.info p.organisation
          end
        end
        d
      }

    end

  end
end