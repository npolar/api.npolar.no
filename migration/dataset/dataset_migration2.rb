require "logger"
require_relative "../../lib/metadata/dataset"

module Metadata
  
  # $ ./bin/npolar_api_migrator http://api:9393/dataset Metadata::DatasetMigration2 --really=false > /dev/null

  class DatasetMigration2

    attr_accessor :log
   
    def migrations
      [ all_principalInvestigators_are_authors,
        all_owners_are_authors,
        data_link_from_dataset_link
      ]
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

  end
end