require 'pp'
require 'hashie'

module Marine
  class Samples < Hashie::Mash

    def self.facets
      [
        "animal_group", "conveyance", "gear", "institution", "preservation", "programs", "sample_types", "station", "substation", "status"
      ]
    end

    def to_solr
      doc = self
      id = doc["id"] ||= doc["_id"]
      rev = doc["rev"] ||= doc["_rev"] ||= nil

      sample_types = doc.fetch("sample_types", "").split(',').map{ |e| e.strip }
     
      solr = {
        :id             => id,
        :rev            => rev,
        :animal_group   => doc.fetch("animal_group", ""),
        :bottomdepth    => doc.fetch("bottomdepth", ""),
        :conveyance     => doc.fetch("conveyance", ""),
        :ctdnr          => doc.fetch("ctdnr", ""),
        :filteredwater  => doc.fetch("filteredwater", ""),
        :flowmeter      => doc.fetch("flowmeter", ""),
        :gear           => doc.fetch("gear", ""),
        :institution    => doc.fetch("institution", ""),
        :instref        => doc.fetch("instref", ""),
        :local_date     => doc.fetch("local_date", ""),
        :metadata_id    => doc.fetch("metadata_id", ""),
        :name           => doc.fetch("name", ""),
        :position_end   => doc.fetch("position_end", ""),
        :position_start => doc.fetch("position_start", ""),
        :preservation   => doc.fetch("preservation", ""),
        :processed_date => doc.fetch("processed_date", ""),
        :programs       => doc.fetch("programs", ""),
        :sample_name    => doc.fetch("sample_name", ""),
        :sample_types   => doc.fetch("sample_types", ""),
        :sampledepth    => doc.fetch("sampledepth", ""),
        :station        => doc.fetch("station", ""),
        :status         => doc.fetch("status", ""),
        :substation     => doc.fetch("substation", ""),
        :utc_date       => doc.fetch("utc_date", "")
      }

      if doc.has_key?("staff")
        if doc["staff"].is_a?(Hash)
          staff = [doc["staff"]]
        else
          staff = doc["staff"]
        end

        staff_info = []

        # for each staff member
        staff.each do |member|
          # flatten staff values (name, phone, etc.)
          staff_info += member.reject{ |k| k == "institution"}.values

          # flatten institute hash
          if member.has_key?("institution") and member["institution"].respond_to?(:each)
            staff_info += [member["institution"].values.join(" ")]
          end
        end

        solr[:staff] = staff_info.join(" | ")
      end

      if doc.has_key?("sample_gear") and doc["sample_gear"].respond_to?(:each)
        solr[:sample_gear] = doc["sample_gear"].values.join(" ")
      end

      text = ""
      solr.to_hash.each do |k,v|
        text += "#{k} = #{v} | "
      end
      solr[:text] = text

      solr
    end
  end
end


