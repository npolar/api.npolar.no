module Biology
  class Sighting
    def self.to_solr
      lambda {|doc| # Hash with symbolized keys

        # Force workspace/collection
        doc[:workspace] = "biology"
        doc[:collection] = "sighting"


        # Map GBIF style lat/long names
        north = doc[:decimalLatitude].to_f
        east = doc[:decimalLongitude].to_f
        doc[:north] = north
        doc[:decimalLatitude] = north
        doc[:east] = east
        doc[:decimalLongitude] = east
        doc[:link_edit] = "/biology/sighting/#{doc[:id]}.json"
        doc[:accept_mimetypes] = ["application/json"]
        doc[:relations] = ["edit"]
        
        begin
          year = doc[:year].nil? ? nil : doc[:year].to_i
          month = doc[:month].nil? ? nil : doc[:month].to_i
          day =  doc[:day].nil? ? nil : doc[:day].to_i
          t = Time.new(year,month,day)
          isodate = t.strftime("%Y-%m-%d")
        rescue ArgumentError
          isodate = "[Bad date]"
          doc[:category] = ["Bad date"]
        end
    
        species = doc[:scientificName]
        if species =~ /\ssp\.$/
          i_species = "<i>#{species.gsub(/\ssp\.$/, "")}</i> sp."
        else
          i_species = "<i>#{species}</i>"
        end

        doc[:title] = "#{i_species} sighting #{isodate} at #{doc[:north]}N #{doc[:east]}E"
        text = []
        text += doc.map {|k,v| "#{k} = #{v.to_json} | "}
        doc[:text] = text.join("")

        doc
      }
    end
  end
end