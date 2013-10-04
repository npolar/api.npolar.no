# encoding: utf-8

# Migrates
# $ ./bin/npolar_api_migrator http://localhost:9393/tracking/deployment TrackingDeploymentMigration0 --really=false > /dev/null

class TrackingDeploymentMigration0

  attr_accessor :log

  def model
    Hashie::Mash.new
  end
 
  def migrations
    [add_vendor_technology_sensors_object_species]
  end

  def select
    lambda {|d| not d.schema }
  end

  def add_vendor_technology_sensors_object_species
      lambda {|d|
        if d.comment == "ATSIridium"
           d.comment == "ATS Iridium"
        end

        vendor, technology = d.comment.split(" ")
        time = d.time.nil? ? "12:00" : d.time.split(":").map {|t|t.to_i}.join(":")
        deployed = DateTime.parse("#{d.deployed}T#{time}")

        d = d.merge({ vendor: vendor,
          technology: technology,
          deployed: deployed.strftime("%Y-%m-%dT%H:%M:%SZ"),
          species: "Ursus maritimus",
          object: "Polar bear",
          sensor_parameters: ["temperature_index", "movement_60s", "movement_24h"],
          year: deployed.year,
          month: deployed.month,
          day: deployed.day
        })
        [:time].each do |k|
          d.delete k
        end
        d
      }
  end

end