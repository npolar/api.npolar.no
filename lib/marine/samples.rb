require 'pp'
require 'hashie'

module Marine
  class Samples < Hashie::Mash

    def self.facets
      [
        "programs"
      ]
    end

    def to_solr
      doc = self

      id = doc["id"] ||= doc["_id"]
      rev = doc["rev"] ||= doc["_rev"] ||= nil

      sample_types = doc.fetch("sample_types", "").split(',').map{ |e| e.strip }

      solr = {
        :id => id,
        :rev => rev,
        :bottomdepth => doc.fetch("bottomdepth", ""),
        :conveyance => doc.fetch("conveyance", ""),
        :flowmeter => doc.fetch("flowmeter", ""),
        :gear => doc.fetch("gear", ""),
        :metadata_id => doc.fetch("metadata_id", ""),
        :name => doc.fetch("name", ""),
        :position_start => doc.fetch("position_start", ""),
        :programs => doc.fetch("programs", ""),
        :sample_id => doc.fetch("sample_id", ""),
        :sample_name => doc.fetch("sample_name", ""),
        :sample_types => sample_types,
        :sampledepth => doc.fetch("sampledepth", ""),
        :station => doc.fetch("station", ""),
        :utc_date => doc.fetch("utc_date", "")
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

      if doc.has_key?("gear") and doc["gear"].respond_to?(:each)
        solr[:gear] = doc["gear"].values.join(" ")
      end

      text = ""
      self.to_hash.each do |k,v|
        text += "#{k} = #{v} | "
      end
      solr[:text] = text

      solr
    end
  end

  def parse_staff(staff_hash)
  end
end


