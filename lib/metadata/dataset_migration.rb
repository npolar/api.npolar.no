require "logger"

# ContactsPeople who quit/died
# org => domain.no

module Metadata
  class DatasetMigration

    attr_writer :log
    # testing before after

    def migrations
      [[email_to_string, locations_to_coverage_and_placenames] # 0
      ]
    end

    def log
      @log ||= Logger.new(STDERR)
    end

    # We don't want multiple emails
    def email_to_string
      [lambda {|d|
        d.investigators? and d.investigators.size > 0 },
      lambda {|d|
        d.investigators = d.investigators.select {|i|
          i.email? and i.email.is_a? Array
        }.map {
          |i|
            i.email = i.email.first
            i
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
              "Dronning Maud Land"
          end
        }.select{|p|not p.nil?}.uniq
        d
      }]
    end

    # groups=["glaciology", "topography"]

    # point_of_contact=[#<Metadata::Dataset email="jack.kohler@npolar.no" name="Geology and geophysics section" org="Norwegian Polar Institute">]
  end
end
