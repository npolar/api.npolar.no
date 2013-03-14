require 'pp'
require 'hashie'

module Marine
  class Lipids < Hashie::Mash

    def self.facets
      [
        "lipid_class", "analysis", "specimen_name", "specimen_sex", "specimen_tissue", "lab", "institution"
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
      solr["collection"] = "lipids"
  
      # flatten specimen hash
      if doc.has_key?("specimen")
        specimen = doc["specimen"]
        if specimen
          solr["specimen_length"]      = specimen.fetch("length", "")
          solr["specimen_name"]        = specimen.fetch("name", "")
          solr["specimen_weight"]      = specimen.fetch("weight", "")
          solr["specimen_comments"]    = specimen.fetch("comments", "")
          solr["specimen_sex"]         = specimen.fetch("sex", "")
          solr["specimen_tissue"]      = specimen.fetch("tissue", "")
          solr["specimen_species"]     = specimen.fetch("species", "")
          solr["lab"]                  = specimen.fetch("lab", "")
          solr["institution"]          = specimen.fetch("institution", "")
        end
      end

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

      filtered = doc.reject{ |k, v| ["id", "rev", "_id", "_rev", "analyses", "specimen"].include? k }
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
