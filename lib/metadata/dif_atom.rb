module Metadata
  class DifAtom

    URI_PREFIX = "http://api.npolar.no/atom"

    REL = {
      "GET DATA" => "#{URI_PREFIX}/link/rel#data",
      "GET SERVICE" => "#{URI_PREFIX}/link/rel#service",
      "VIEW EXTENDED METADATA" => "#{URI_PREFIX}/link/rel#metadata",
      "GET RELATED DATA SET METADATA (DIF)" => "#{URI_PREFIX}/link/rel#metadata",
      "GET RELATED SERVICE METADATA (SERF)" => "#{URI_PREFIX}/link/rel#metadata",
      "VIEW PROJECT HOME PAGE" => "#{URI_PREFIX}/link/rel#project",
    }

    #GET RELATED VISUALIZATION
    #VIEW RELATED INFORMATION


    def extract_rel(type, subtype = nil)
      rel = REL[type] || "related"
      rel
    end
  





##
      # Atom-like Hash from DIF Hash
      #
      def atom_from_dif(dif)
        atom = {
          #"author" => extract_author #{ "name" => "Norwegian Polar Institute", "uri" => "http://data.npolar.no", "email" => ""},
          "contributors" => extract_contributors(dif["Personnel"]),
          "summary" => dif["Summary"]["Abstract"],
          "id" => dif["id"].nil? ? dif["_id"] : dif["id"],
          "links" => extract_links(dif),
          "title" => dif["Entry_Title"],
          "published" => dif["DIF_Creation_Date"]+"T12:00:00Z",
          "updated" => dif["Last_DIF_Revision_Date"]+"T12:00:00Z",
          "rights" => dif["Use_Constraints"],
          "draft" => "no",
          "dif:Entry_ID" => dif["Entry_ID"],
        }

        if dif["Private"] == "True"
          atom["draft"] = "yes"
        end

        unless dif["Data_Center"].nil?
          dif["Data_Center"].each do | data_center |
            url = data_center["Data_Center_URL"]
            if url =~ /http\:\/\/(www\.)?npolar\.no/
              url = "http://data.npolar.no"
            end

            atom["links"] << { "href" => url, "rel" => "http://api.npolar.no/atom/category#datacenter" }
            extract_contributors(data_center["Personnel"]).each do |c|
              atom["contributors"] << c
            end
          end
        end
        #Data_Center => linkrel=htpp...#Data_Center?

        unless dif["Spatial_Coverage"].nil?
          atom["north"] = dif["Spatial_Coverage"].first["Northernmost_Latitude"],
          atom["east"] = dif["Spatial_Coverage"].first["Easternmost_Longitude"],
          atom["west"] = dif["Spatial_Coverage"].first["Westernmost_Longitude"],
          atom["south"] = dif["Spatial_Coverage"].first["Southernmost_Latitude"]
        end

        # << add contributors from Data Center

        #REQUIRED = ["Data_Center", "Entry_ID", "Entry_Title", "ISO_Topic_Category", "Metadata_Name", "Metadata_Version", "Parameters", "Summary"]


        atom["categories"] = []
        
        unless dif["ISO_Topic_Category"].nil?
          dif["ISO_Topic_Category"].each do |isotc|
            atom["categories"] << { "term" => isotc, "scheme" => "http://isotc211.org" }
          end
        end

        unless dif["Project"].nil?
          dif["Project"].each do |p|
            atom["categories"] << { "term" => p["Short_Name"], "scheme" => "#{URI_PREFIX}/category#project", "label" => p["Long_Name"] }
          end
        end

        unless dif["IDN_Node"].nil?
          dif["IDN_Node"].each do |p|
            atom["categories"] << { "term" => p["Short_Name"], "scheme" => "#IDN_Node", "label" => p["Long_Name"] }
          end
        end


        unless dif["Keyword"].nil?
          dif["Keyword"].each do | keyword |
            atom["categories"] << { "term" => keyword, "scheme" => "#keyword"}
          end
        end

        unless dif["Parameters"].nil?
          atom["dif:Parameters"] == dif["Parameters"]
        end

    
        # Delete DIF data that is mapped above
        dif.delete "Personnel"
        dif.delete "Related_URL"
        dif.delete "Use_Constraints"
        dif.delete "DIF_Creation_Date"
        dif.delete "Last_DIF_Revision_Date"
        dif.delete "ISO_Topic_Category"
        dif.delete dif["Summary"]["Abstract"]
        if dif["Spatial_Coverage"] and dif["Spatial_Coverage"].size == 1
          dif.delete "Spatial_Coverage"
        end


        #"Metadata_Version":"9.8.2","Originating_Metadata_Node":"NPI/RiS","Data_Set_Language":["English"],"IDN_Node":[{"Short_Name":"ARCTIC/NO"},{"Short_Name":"ARCTIC"}]


        atom["source"] = { "dif" => dif }
        atom
      end

      # Beware of multiple roles, emails...
      def extract_contributors(personnel)

        return [] if personnel.nil?

        personnel.map { |p| {
            "email" => p["Email"].nil? ? "" : p["Email"],
            "first_name" =>  "#{p["First_Name"]} #{p["Middle_Name"]}".gsub(/\s+$/, ""),
            "last_name" =>  p["Last_Name"],
            "role" => p["Role"],
          }
        }
      end

      def extract_links(dif)
        return [] if dif["Related_URL"].nil?
        dif["Related_URL"].map { |r| extract_link_or_links(r) }.flatten
      end

      # A DIF Related_URL may contain many URLs
      def extract_link_or_links(r)
        links = []
        if r["URL"].is_a? String
          url = r["URL"]
          r["URL"] = [url]
        end
        r["URL"].each do | url |
          links << {
            "title" => r["Description"],
            "href" => r["URL"].first,
            "rel" => extract_rel(r["URL_Content_Type"]["Type"]),
            "type" => nil,
            "dif:type" => r["URL_Content_Type"]["Type"],
            "dif:subtype" => r["URL_Content_Type"]["Subtype"],
          }
        end
        links

      end

  end
end