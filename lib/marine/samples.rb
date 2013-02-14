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
      puts "to_solr"
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
      
      text = ""
      self.to_hash.each do |k,v|
        text += "#{k} = #{v} | "
      end
      solr[:text] = text

      pp solr
      solr
    end
  end
end


