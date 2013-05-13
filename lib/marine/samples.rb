require 'pp'
require 'hashie'

module Marine
  class Samples < Hashie::Mash

    def self.facets
      [
        "workspace", "collection", "animal_group", "conveyance", "gear", "institution", "preservation", "programs", "sample_types", "station", "substation", "status", "year"
      ]
    end

    def to_solr
      doc = self
      id = doc["id"] ||= doc["_id"]
      rev = doc["rev"] ||= doc["_rev"] ||= nil

      solr = {
        :id                => id,
        :rev               => rev,
        :animal_group      => doc.fetch("animal_group", ""),
        :bottomdepth       => doc.fetch("bottomdepth", ""),
        :conveyance        => doc.fetch("conveyance", ""),
        :ctdnr             => doc.fetch("ctdnr", ""),
        :filteredwater     => doc.fetch("filteredwater", ""),
        :flowmeter_start   => doc.fetch("flowmeter_start", ""),
        :flowmeter_stop    => doc.fetch("flowmeter_stop", ""),
        :gear              => doc.fetch("gear", ""),
        :institution       => doc.fetch("institution", ""),
        :instref           => doc.fetch("instref", ""),
        :metadata_id       => doc.fetch("metadata_id", ""),
        :name              => doc.fetch("name", ""),
        :latitude_start    => doc.fetch("latitude_start", ""),
        :longitude_start   => doc.fetch("longitude_start", ""),
        :latitude_end      => doc.fetch("latitude_end", ""),
        :longitude_end     => doc.fetch("longitude_end", ""),
        :preservation      => doc.fetch("preservation", ""),
        :programs          => doc.fetch("programs", ""),
        :sample_name       => doc.fetch("sample_name", ""),
        :sample_types      => doc.fetch("sample_types", ""),
        :sample_depth_from => doc.fetch("sample_depth_from", ""),
        :sample_depth_to   => doc.fetch("sample_depth_to", ""),
        :station           => doc.fetch("station", ""),
        :status            => doc.fetch("status", ""),
        :substation        => doc.fetch("substation", ""),
        :title             => doc.fetch("title", ""),
        :workspace         => "marine",
        :collection        => "samples"
      }

      # we can't let in any blank dates or solr will scream
      utc_date = doc.fetch("utc_date", "")
      if !utc_date.empty?
        solr[:year] = DateTime.parse(utc_date).year
        solr[:utc_date] = utc_date
      end

      local_date = doc.fetch("local_date", "")
      if !local_date.empty?
        solr[:local_date] = local_date
      end

      processed_date = doc.fetch("processed_date", "")
      if !processed_date.empty?
        solr[:processed_date] = processed_date
      end

      # flatten sample_staff when needed
      if doc.has_key?("sample_staff")
        if doc["sample_staff"].is_a?(Hash)
          staff = [doc["sample_staff"]]
        else
          staff = doc["sample_staff"]
        end

        staff_info = []

        if staff.is_a?(Array)
          # for each staff member
          staff.each do |member|
            # flatten staff values (name, phone, etc.)
            staff_info += member.reject{ |k| k == "institution"}.values

            # flatten institute hash
            if member.has_key?("institution") and member["institution"].respond_to?(:each)
              staff_info += [member["institution"].values.join(" ")]
            end
          end
        end

        solr[:staff] = staff_info.join(" | ")
      end

      if doc.has_key?("sample_gear") and doc["sample_gear"].respond_to?(:each)
        solr[:sample_gear] = doc["sample_gear"].values.join(" ")
      end

      text = ""
      # index species information
      if doc.has_key?("abundances")
        doc["abundances"].each_with_index do |abund, index|
          if abund.has_key? "animal"
            abund["animal"].each do |k, v|
              text += "#{k}_#{index} = #{v} | "
            end
          end
        end
      end

      # index lipids info
      if doc.has_key?("lipids")
        doc["lipids"].each_with_index do |lipid, index|
          if lipid.has_key? "specimen"
            tissue = lipid["specimen"].fetch("tissue", "")
            species = lipid["specimen"].fetch("species", "")
            name = lipid["specimen"].fetch("name", "")
            text += "tissue_#{index} = #{tissue} | "
            text += "species_#{index} = #{species} | "
            text += "specimen_name_#{index} = #{name} | "
          end
          if lipid.has_key? "analyses"
            lipid["analyses"].each_with_index do |analysis, index|
              lipid_class = analysis.fetch("lipid_class", "")
              text += "lipid_class_#{index} = #{lipid_class} |"
            end
          end
        end
      end

      # everything else
      solr.to_hash.each do |k,v|
        text += "#{k} = #{v} | "
      end
      solr[:text] = text

      solr
    end
  end
end


