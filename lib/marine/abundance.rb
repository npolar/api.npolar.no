require 'pp'
require 'hashie'

module Marine
  class Abundance < Hashie::Mash

    def self.facets
      [
        "phylum", "subphylum", "class", "order", "family", "genus", "name_sci", "stage_name"
      ]
    end

    def to_solr
      doc = self
      id = doc["id"] ||= doc["_id"]
      rev = doc["rev"] ||= doc["_rev"] ||= nil

      solr = doc
      solr["id"] = id
      solr["rev"] = rev
 
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


