require "hashie"
require "json-schema"

module Metadata

  # Dataset metadata model class
  #
  # [Functionality]
  #   * Holds metadata in a extended Hash (Hashie::Mash)
  #   * Transform to Solr-style Hash (for creating Solr JSON)
  #   * Transform to DIF XML Hash (for creating DIF XML)
  #
  # [License]
  #   This code is licensed under the {http://www.gnu.org/licenses/gpl.html GNU General Public License Version 3} (GPLv3)
  #
  # @author Ruben Dens
  # @author Conrad Helgeland
  #     #model.schema = File.read(File.expand_path(File.join(".", "lib", "metadata/dataset-schema.json")))
  
  class Dataset < Hashie::Mash
    
    attr_accessor :schema

    BASE = "/metadata/dataset/"
    
    DIF_SCHEMA_URI = "http://gcmd.nasa.gov/Aboutus/xml/dif/dif.xsd"

    SCHEMA_URI = {
      "dif" =>  DIF_SCHEMA_URI,
      "json" => "http://api.npolar.no/schema/metadata-dataset.json",
      "xml" => DIF_SCHEMA_URI
    }

    class << self
      attr_accessor :formats, :accepts, :base
    end

    def self.country_codes
      #  http://en.wikipedia.org/wiki/Arctic_Council + AQ
      ["CA", "DK", "GL", "FI", "FO", "IS", "NO", "RU", "SW", "AQ", "US"].sort
    end

    def self.facets
      ["methods", "parameter", "gcmd_keywords", "person", "methods", "protocols", "relations", "sets",
        "investigators", "investigator_emails", "org", "project", "draft", "link", "groups", "set", "category", "country", "placename",
        "iso_3166-1", "iso_3166-2", "hemisphere", "source", "year", "month", "day", "editor", "referenceYear",
        "tags", "groups", "licences", "rights"]
    end

    # code or URI?
    #def self.licenses
    #  ["http://data.norge.no/nlod/no/1.0", "http://creativecommons.org/licenses/by/3.0/no/"]
    #end

    def self.licences
      ["http://data.norge.no/nlod/no/1.0",
      "http://data.norge.no/nlod/en/1.0",
      "http://creativecommons.org/licenses/by/3.0/",
      "http://creativecommons.org/licenses/by/3.0/no/"]
    end


    def self.licence_codes
      ["nlod", "cc-by", "cc0"]
    end

    def self.mimetypes
      ["application/json", "application/xml"]
    end

    def self.schemas
      [schema_uri("json"), schema_uri("xml")]
    end

    def self.sets
      oai_sets.map {|set| set[:spec] }
    end

    def self.schema_uri(format="json")
      if SCHEMA_URI.key? format
        SCHEMA_URI[format]
      else
        raise ArgumentError, "Unknown schema format"
      end
    end



    #<IDN_Node>
    #<Short_Name>IPY</Short_Name>
    #</IDN_Node>
    #<IDN_Node>
    #<Short_Name>AMD/NO</Short_Name>
    #</IDN_Node>
    #<IDN_Node>
    #<Short_Name>ARCTIC/NO</Short_Name>
    #</IDN_Node>
    #<IDN_Node>
    #<Short_Name>ARCTIC</Short_Name>
    #</IDN_Node>
    #<IDN_Node>
    #<Short_Name>AMD</Short_Name>
    #</IDN_Node>
    #<IDN_Node>
    #<Short_Name>DOKIPY</Short_Name>
    #</IDN_Node>

    #biology ecotox gcmd map metadata placename ocean seaice tracking
     #def dif_discipline
     #  case groups
     #    when "biodiveristy" then "BIOLOGY"
     #    when "ecotoxicology" then "" # DIF "TOXICOLOGY" is under "MEDICAL SCIENCES"
     #  # geology = GEOLOGY
     #  # geohysics = GEOPHYSICS
     #  # glaciology = "",
     #  # topography = "",
     #  # oceanography = OCEANOGRAPHY # top level? or under physical sciences?
     #  # seaice = ""
     #  
     #  end
     #end

    def self.oai_sets
      [ {:spec => "arctic", :name => "Arctic datasets"},
        {:spec => "antarctic", :name => "Antarctic datasets"},
        {:spec => "IPY:NO", :name => "International Polar Year: Norway", :description => "Norwegian contributions to the International Polar Year"},
        {:spec => "IPY", :name => "International Polar Year", :description => "Datasets from the International Polar Year (2007-2008)"},
        {:spec => "cryoclim.net", :name => "Cryoclim", :description => "Climate monitoring of the cryosphere, see http://cryoclim.net"},
        {:spec => "nmdc", :name => "Norwegian Marine Data Centre", :description => "Marine datasets"},
        {:spec => "gcmd", :name => "Global Change Master Directory" }
      ]
    end

    def self.summary
      "Dataset metadata, in particular DIF XML targeted at NASA's Global Change Master Directory."
    end

    def self.title
      "Norwegian Polar Institute's datasets"
    end
    
    def to_solr
      doc = self

      id = doc["id"] ||=  doc["_id"]
      rev = doc["rev"] ||=  doc["_rev"] ||= nil

      solr = { :id => id,
        :rev => rev,
        :title => doc.title,
        :group => doc["group"],
        :tags => doc["tags"],
        :sets => doc["sets"],
        :iso_topics => doc["iso_topics"],
        :licences => doc["licenses"],
        :draft => doc["draft"],
        :workspace => "metadata",
        :collection => "dataset",
        :links => doc.links,
        :licences => doc.licences,
        :rights => doc.rights,
        :formats => self.class.formats,
        :accepts => self.class.accepts,
        :accept_mimetypes => self.class.mimetypes,
        :accept_schemas => self.class.schemas,
        :relations => ["edit", "alternate"]
      }
        if doc.science_keywords.respond_to? :map
          cat = []
          cat += doc["science_keywords"].map {|keyword| [keyword.Category ,keyword.Topic, keyword.Term, keyword.Variable_Level_1, keyword.Variable_Level_2, keyword.Variable_Level_3 ]}
          cat = cat.flatten.uniq
          solr[:category] = cat
        end
        
        if doc.key? "investigators"
          solr[:investigators] = doc["investigators"].map {|i| "#{i["first_name"]} #{i["last_name"]}"}
          solr[:investigator_emails] = doc["investigators"].select {|i|i.email?}.map {|i| "#{i["email"].first}"}
        end
        
        if doc.key? "contributors"
          solr[:contributors] = doc["contributors"].map {|i| "#{i["first_name"]} #{i["last_name"]}"}
          solr[:contributors_emails] = doc["contributors"].select {|i|i.email?}.map {|i| "#{i["email"].first}"}
        end

        # Reduce locations to 1 bounding box
        if doc.locations.respond_to? :map
          solr[:north] = doc.locations.select {|l|l.north?}.map {|l|l.north}.max
          solr[:east]  = doc.locations.select {|l|l.east?}.map  {|l|l.east}.max
          solr[:south] = doc.locations.select {|l|l.south?}.map {|l|l.south}.min
          solr[:west]  = doc.locations.select {|l|l.west?}.map  {|l|l.west}.min
          unless solr.key? :placename
            solr[:placename] = []
          end
          solr[:placename] += doc.locations.select {|l|l.placename? and l.placename.size > 0 }.map {|l|l.placename}

        end

        if doc.links.respond_to? :map
          relations = doc.links.select {|l|l.rel?}
          solr[:relations] += relations.map {|l|l.rel}
          relations.each do |l|
            solr[:"link_#{l.rel}"] = l.href
          end
          
        end

      text = []
      text += solr.map {|k,v| "#{k} = #{v} | "}
      solr[:text] = text.join("")

      
      solr[:link_edit] = "#{BASE.gsub(/\/$/, "")}/#{id}.json"
      solr[:link_html] = "http://data.npolar.no/metadata/dataset/#{id}"
      solr[:link_dif] = "/metadata/dataset/#{id}.dif"
      solr[:link_iso] = "/metadata/dataset/#{id}.iso"


      solr

    end
    
    def from_dif
    end
    
    def to_dif
    end
    
    def uri(id)
      self.class.uri + id
    end
    
    def valid?
      JSON::Validator.validate( schema, self )
    end
    
    def validate
      JSON::Validator.fully_validate( schema, self )
    end
    
  end
  
end