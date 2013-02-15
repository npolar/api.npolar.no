require 'pp'
require 'hashie'

module Marine
  class Abundance < Hashie::Mash

    def self.facets
      [
        "name"
      ]
    end

    def to_solr
      doc = self

      solr = doc

      id = doc["id"] ||= doc["_id"]
      rev = doc["rev"] ||= doc["_rev"] ||= nil

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


