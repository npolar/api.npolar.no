# https://github.com/intridea/hashie
class AtomHash < Hash
  
  TEXT_KEY = ["id", "title", "subtitle", "content", "summary", "generator", "icon", "rights", "updated", "edited", "published" ]

  def [](key)
    # key exist?
    val = super(key)
    if val.nil? and TEXT_KEY.include? key
      val = ""
    end
    val.nil? ? [] : val
  end
end

module Metadata

  # Converts metadata objects between DIF hashes and Atom-like hashes

  # Supported
  #  
  # All required DIF elements
  # * REQUIRED = ["Data_Center", "Entry_ID", "Entry_Title", "ISO_Topic_Category", "Metadata_Name", "Metadata_Version", "Parameters", "Summary"]
  # * HIGHLY_RECOMMENDED = ["Access_Constraints", "Data_Resolution", "Data_Set_Citation", "Data_Set_Language", "Data_Set_Progress", "Distribution",
  #     "Sensor_Name", "Location", "Paleo_Temporal_Coverage", "Personnel", "Source_Name", "Project", "Quality", "Related_URL", "Spatial_Coverage", "Temporal_Coverage", "Use_Constraints"]

  # Not supported (i.e. no conversion of)
  # * Data_Resolution
  # * Multimedia_Sample [link?]
  # * Related_URL/URL_Content_Type/Subtype
  # * Sensor_Name
  # * Future_DIF_Review_Date
  # * Summary/Purpose
  # * Minimum_Altitude
  # * Maximum_Altitude
  # * Minimum_Depth
  # * Maximum_Depth
  # * "Fax", "Postal_Code", "Phone", "Multimedia_Sample", "Paleo_Temporal_Coverage"
  
  #<xs:element ref="DIF_Revision_History" minOccurs="0" maxOccurs="1"/>
  #<xs:element ref="Future_DIF_Review_Date" minOccurs="0" maxOccurs="1"/>
  #<xs:element ref="IDN_Node" minOccurs="0" maxOccurs="unbounded"/>
  #<xs:element ref="Originating_Metadata_Node" minOccurs="0" maxOccurs="1"/>
  #<xs:element ref="Paleo_Temporal_Coverage" minOccurs="0" maxOccurs="unbounded"/>
  #<xs:element ref="Data_Resolution" minOccurs="0" maxOccurs="unbounded"/>
  #<xs:element ref="Quality" minOccurs="0" maxOccurs="1"/>

  class DifAtom

    DIF = "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/"

    ISO_TOPIC_CATEGORY = "http://isotc211.org"

    URI_PREFIX = "http://api.npolar.no/atom"

    REL = {
      "GET DATA" => "#{URI_PREFIX}/link/rel#data",
      "GET SERVICE" => "#{URI_PREFIX}/link/rel#service",
      "VIEW EXTENDED METADATA" => "#{URI_PREFIX}/link/rel#metadata",
      "GET RELATED DATA SET METADATA (DIF)" => DIF,
      "GET RELATED SERVICE METADATA (SERF)" => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/serf/",
      "VIEW PROJECT HOME PAGE" => "#{URI_PREFIX}/link/rel#project",
      "VIEW RELATED INFORMATION" => "related",
      "GET RELATED VISUALIZATION" => "#{URI_PREFIX}/link/rel#graph"
    }

    ROLE = {
      "Investigator" => "",
    }

    #GET RELATED VISUALIZATION
    #VIEW RELATED INFORMATION    

    def extract_rel(type, subtype = nil)
      REL[type] || "related"
    end

    def links_by_rels(links, rels=REL.invert.keys)
      links.select {|link| rels.include? link["rel"] }
    end

    def links_by_rel(links, rel)
      return [] if links.nil? or links.empty? or rel.empty?
      links.select {|link| link["rel"] =~ /#{rel}$/ }
    end

    def categories_by_scheme(categories, scheme)
      return [] if categories.nil? or categories.empty? or scheme.empty?
      categories.select {|category| category["scheme"] =~ /#{scheme}$/ }
    end
  
    #
    # Atom-like Hash from DIF Hash
    #
    
    def atom_from_dif(dif)
      atom = {
        "author" => extract_author, #{ "name" => "Norwegian Polar Institute", "uri" => "http://data.npolar.no", "email" => ""},
        "title" => dif["Entry_Title"],
        "id" => dif["Entry_ID"].nil? ? dif["_id"] : dif["Entry_ID"],
        "contributors" => extract_contributors(dif["Personnel"]),
        "summary" => dif["Summary"]["Abstract"],
        "links" => extract_links(dif),
        "categories" => [],
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
        atom["geo"] = []
        
        dif["Spatial_Coverage"].each do | location |
          atom["geo"] << {
            "north" => location["Northernmost_Latitude"],
            "east" => location["Easternmost_Longitude"],
            "west" => location["Westernmost_Longitude"],
            "south" => location["Southernmost_Latitude"]
          }
        end
      end

      # << add contributors from Data Center

      #REQUIRED = ["Data_Center", "Entry_ID", "Entry_Title", "ISO_Topic_Category", "Metadata_Name", "Metadata_Version", "Parameters", "Summary"]

      unless dif["ISO_Topic_Category"].nil?
        dif["ISO_Topic_Category"].each do |isotc|
          atom["categories"] << { "term" => isotc, "scheme" => ISO_TOPIC_CATEGORY }
        end
      end

      unless dif["Project"].nil?
        dif["Project"].each do |p|
          atom["categories"] << { "term" => p["Short_Name"], "scheme" => "http://gcmd.nasa.gov/Aboutus/xml/dif/dif.xsd#Project", "label" => p["Long_Name"] }
        end
      end

      unless dif["IDN_Node"].nil?
        dif["IDN_Node"].each do |p|
          atom["categories"] << { "term" => p["Short_Name"], "scheme" => "http://gcmd.nasa.gov/Aboutus/xml/dif/dif.xsd#IDN_Node", "label" => p["Long_Name"] }
        end
        dif.delete "IDN_Node"
      end

      unless dif["Keyword"].nil?
        dif["Keyword"].each do | keyword |
          atom["categories"] << { "term" => keyword, "scheme" => "#{URI_PREFIX}/category#keyword"}
        end
        dif.delete "Keyword"
      end

      unless dif["Data_Set_Progress"].nil?
        atom["categories"] << { "term" => dif["Data_Set_Progress"], "scheme" => "#{URI_PREFIX}/category#datastatus"}
        dif.delete "Data_Set_Progress"
      end

      unless dif["Parameters"].nil?
        atom["dif:Parameters"] = dif["Parameters"]
      end

      # Delete DIF data that is mapped above
      dif.delete "Personnel"
      dif.delete "Related_URL"
      dif.delete "Use_Constraints"
      dif.delete "DIF_Creation_Date"
      dif.delete "Last_DIF_Revision_Date"
      dif.delete "ISO_Topic_Category"
      dif.delete dif["Summary"]["Abstract"]
      dif.delete "Spatial_Coverage"

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
  
    def extract_author
      "AUTHOR"
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
      #p r #r["URL_Content_Type"] #["Type"]

      r["URL"].each do | url |
        if r.key? "URL_Content_Type" and r["URL_Content_Type"].key? "Type"
          type = r["URL_Content_Type"]["Type"]
        else
          type = ""
        end
        links << {
          "title" => r["Description"],
          "href" => r["URL"].first,
          "rel" => extract_rel(type),
          "type" => nil
        }
      end
      links

    end

    # DIF hash from Atom hash
    # http://gcmd.nasa.gov/Aboutus/xml/dif/dif.xsd
    def dif(atom) 
        
      #<xs:element ref="Entry_ID" minOccurs="1" maxOccurs="1"/>
      #<xs:element ref="Entry_Title" minOccurs="1" maxOccurs="1"/>
      #<xs:element ref="Data_Set_Citation" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Personnel" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Discipline" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Parameters" minOccurs="1" maxOccurs="unbounded"/>
      #<xs:element ref="ISO_Topic_Category" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Keyword" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Sensor_Name" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Source_Name" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Temporal_Coverage" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Data_Set_Progress" minOccurs="0" maxOccurs="1"/>
      #<xs:element ref="Spatial_Coverage" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Location" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Project" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Access_Constraints" minOccurs="0" maxOccurs="1"/>
      #<xs:element ref="Use_Constraints" minOccurs="0" maxOccurs="1"/>
      #<xs:element ref="Data_Set_Language" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Originating_Center" minOccurs="0" maxOccurs="1"/>
      #<xs:element ref="Data_Center" minOccurs="1" maxOccurs="unbounded"/>
      #<xs:element ref="Distribution" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Multimedia_Sample" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Reference" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Summary" minOccurs="1" maxOccurs="1"/>
      #<xs:element ref="Related_URL" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Parent_DIF" minOccurs="0" maxOccurs="unbounded"/>
      #<xs:element ref="Metadata_Name" minOccurs="1" maxOccurs="1"/>
      #<xs:element ref="Metadata_Version" minOccurs="1" maxOccurs="1"/>

      source_dif = {}
      if atom["source"] and atom["source"]["dif"]
        source_dif = atom["source"]["dif"]
      end
      
      dif = {}
      dif = dif.merge(source_dif)
      
      if atom["id"] == nil
        atom["id"] = atom["_id"]
      end
      
      dif = dif.merge({
        "Entry_ID" => atom["dif:Entry_ID"] || atom["id"],
        "Entry_Title" => atom["title"],
        "Data_Set_Citation" => [],
        "Personnel" => [], #personnel_from_contributors(atom["contributors"]),
        "Related_URL" => [],  
        "Discipline" => [],
        "Data_Center" => [],
        "Parameters" => atom["dif:Parameters"],
        "ISO_Topic_Category" => categories_by_scheme(atom["categories"], ISO_TOPIC_CATEGORY).map {| c | c["term"]},
        "Summary" => { "Abstract" => atom["summary"], "Purpose" => "" },
        "DIF_Creation_Date" => atom["published"].split("T")[0],
        "Last_DIF_Revision_Date" => atom["updated"].split("T")[0],
        "Private" => ""
      }) 
      
      links_by_rel(atom["links"], "#datacenter").each do | l |
        dif["Data_Center"] << {"Data_Center_URL" => l["href"], "Personnel" => [] }        
      end
      
      #REQUIRED = ["Data_Center", "Entry_ID", "Entry_Title", "ISO_Topic_Category", "Metadata_Name", "Metadata_Version", "Parameters", "Summary"]
      # Related_URL from links with known relations
      links_by_rels(atom["links"], REL.invert.keys).each do | link |
        dif["Related_URL"] << Related_URL(link)
      end
      
      dif
    end
    
    def rel(anchor)
      anchors = REL.invert.keys.map {|rel| rel.split("#")[1] }
      if anchors.include? anchor
        links_by_rel()
      else
        
      end
    end
    
    def Related_URL(link)
      r = { "URL_Content_Type" => {}, "URL" => [], "Description" => nil }
      r["URL"] << link["href"]
      r["URL_Content_Type"]["Type"] = URL_Content_Type_Type(link["rel"])
      r["Description"] = link["title"]
      r
    end
    
    def URL_Content_Type_Type(rel)
      REL.invert[rel]
    end
    
  end
end