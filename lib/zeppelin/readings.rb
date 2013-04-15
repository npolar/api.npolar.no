require 'hashie'

module Zeppelin
  class Readings < Hashie::Mash

    def self.facets
      []
    end

    def to_solr
      doc = self
      id = doc["id"] ||= doc["_id"]
      rev = doc["rev"] ||= doc["_rev"] ||= nil

      solr = doc
      solr[:id] = id
      solr[:rev] = rev

      # everything
      solr.to_hash.each do |k,v|
        text += "#{k} = #{v} | "
      end
      solr[:text] = text
      puts solr

      solr
    end
  end
end


