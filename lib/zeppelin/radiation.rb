require 'hashie'

module Zeppelin
  class Radiation < Hashie::Mash

    def self.facets
      ['DIF_SOLAR_SENSITIVITY', 'Date_Time', 'MAX_DIF_SOLAR', 'MAX_IR_SOLAR']
    end

    def to_solr
      doc = self
      id = doc["id"] ||= doc["_id"]
      rev = doc["rev"] ||= doc["_rev"] ||= nil

      solr = doc
      solr[:id] = id
      solr[:rev] = rev

      # flatten units hash
      if doc.has_key? "units"
        solr[:units] = doc["units"].flatten
      end

      # everything
      text = ""
      solr.to_hash.each do |k,v|
        if !v.respond_to?(:each)
          text += "#{k} = #{v} | "
        end
      end
      solr[:text] = text
      solr
    end
  end
end


