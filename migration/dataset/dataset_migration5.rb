require "logger"

module Metadata

  # What
  # Make sure dataset.to_xml produces valid DIF XML
  
  # Production
  # When
  
  # $ ./bin/npolar-api-migrator /dataset ::Metadata::DatasetMigration5 --really=false > /dev/null
  class DatasetMigration5

    attr_accessor :log
    
    @@r = []
   
    def migrations
      [check_dif_xml_valid, add_at_least_1_person, comment_from_gcmd_references, cleanup_rights, cleanup_restrictions]
    end
    
    def model
      ::Metadata::Dataset.new
    end
    
    def check_dif_xml_valid
      lambda {|d|
        schema = ::Gcmd::Schema.new
        d = model.class.new(d)
        
        log.info d.title
        
        errors = schema.validate_xml( d.to_dif )
        
        if errors.any?
          log.warn errors.to_json
          d.errors = errors
        end
        d
      }
    end
    
    def add_at_least_1_person
      lambda {|d|
        
        if d.people.none?
          log.fatal d.organisations.to_json
          log.fatal d.id
        end
        d
      }
    end
    
    def cleanup_rights
      lambda {|d|
        if d.rights =~ /^Open data/
          d.rights = "Open data: Free to reuse if attributed to the Norwegian Polar Institute"
        elsif d.rights = /^Protected/
          d.rights = "Protected by Norwegian copyright law"
          d.licences = ["http://lovdata.no/dokument/NL/lov/1961-05-12-2"]
        end
        d
      }
    end
    
    def cleanup_restrictions
      lambda {|d|
        if d.restrictions?
          if d.restrictions =~ /^(Owned b[yu] NPI|Contact Norwegian Polar Institute|Please contact|Based on contact|Contact|withhold|NPI has unrestricted user rights|Free access to data)/ui
            d.delete :restrictions
          elsif d.restrictions =~ /creativecommons.org|Attribution/
            d.delete :restrictions
          else
            @@r << [d.id, d.title, d.restrictions ]
            log.warn JSON.pretty_generate(@@r)
          end
        end
        d
      }
    end
    
    def comment_from_gcmd_references
      lambda {|d|
        if d.gcmd? and d.gcmd.references?
          unless d.comment?
            d.comment = ""
          end
          d.comment += "\nReferences: "+d.gcmd.references.uniq.join("\n").strip
          log.info d.comment
        end
        d
      }
    end
    
  end
end

