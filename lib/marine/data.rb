require 'pp'
require 'hashie'

module Marine
  class Data < Hashie::Mash

    def self.facets
      [
        "phylum", "subphylum", "class", "order", "family", "genus", "name_sci", "stage_name"
      ]
    end

    def to_solr
      doc = self.to_hash
      id = doc["id"] ||= doc["_id"]
      rev = doc["rev"] ||= doc["_rev"] ||= nil

      solr = {}
      solr["id"] = id
      solr["rev"] = rev

      doc.each do |k, v|
        if k == "animal"
          doc["animal"].each do |ani_k, ani_v|
            solr[ani_k] = ani_v
          end
        elsif !["id", "rev", "_id", "_rev"].include? k 
          solr[k] = v
        end
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


