require "logger"

module Metadata

  # New /dataset "sets" - using domain names and lowercase
  # https://github.com/npolar/api.npolar.no/issues/20
  
  # Production
  # 2014-05-06T09:26:43Z http://api.npolar.no/editlog/8be692ea-6b28-4b5e-b947-e56894533c2d
  
  # $ ./bin/npolar-api-migrator /dataset ::Metadata::DatasetMigration4 --really=false > /dev/null
  class DatasetMigration4

    attr_accessor :log
   
    def migrations
      [new_sets]
    end

    def new_sets
      lambda {|d|
        if d.sets?
          if d.sets.any? {|set| set =~ /^(nmdc|gcmd|ipy)$/ui }
            d.sets = d.sets.reject {|set| set =~ /dokipy/ui }
            
            d.sets = d.sets.map {|set|
              if set =~ /gcmd/ui
                set = "gcmd.nasa.gov"
              elsif set =~ /ipy/ui
                set = "ipy.org" # beware ipy.org => BAS while www.ipy.org is still functional
              elsif set =~ /nmdc/ui or d.topics.include? "marine"
                set = "marine"
              end
              set
            }
            log.info d.sets
          end
        else
          log.warn "No set: #{d.id}"
          d.sets = []
        end
                
        if d.topics.include? "marine" and not d.sets.include? "marine"
          d.sets << "marine"
        end
        
        if d.topics.include? "glaciology" and not d.sets.include? "glaciology"
          d.sets << "glaciology"
        end
        
        d
      }
    end

  end
end