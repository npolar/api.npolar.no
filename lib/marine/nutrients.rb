require 'pp'
require 'hashie'

module Marine
  class Nutrients < Hashie::Mash

    def self.facets
      [
        "nutrient", "average", "stdev", "unit"
      ]
    end

    def to_solr
      doc = self.to_hash
      id = doc["id"] ||= doc["_id"]
      rev = doc["rev"] ||= doc["_rev"] ||= nil

      solr = {}
      solr["id"] = id
      solr["rev"] = rev
      solr["workspace"] = "marine"
      solr["collection"] = "nutrients"

      if doc.has_key?("analyses")
        doc["analyses"].each do |analysis|
          analysis.each do |k, v|
            if !solr.has_key? k
              solr[k] = [v]
            else
              solr[k] << v
            end
          end
        end
      end

      filtered = doc.reject{ |k, v| ["id", "rev", "_id", "_rev", "analyses"].include? k }
      filtered.each do |k, v|
        solr[k] = v
      end 
 
      text = ""
      solr.each do |k,v|
        text += "#{k} = #{v} | "
      end
      solr["text"] = text

      pp solr
      solr
    end
  end
end
