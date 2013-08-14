require "hashie"

module Metadata

  # Dataset model
  #
  # [Functionality]
  #   * Holds metadata in a extended Hash (Hashie::Mash)
  #   * Transform to Solr-style Hash (for creating Solr JSON)
  #   * Transform to DIF XML Hash (for creating DIF XML)
  #
  # [License]
  #   {http://www.gnu.org/licenses/gpl.html GNU General Public License Version 3} (GPLv3)
  #
  # @author Ruben Dens
  # @author Conrad Helgeland
  
  class Dataset < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator

    BASE = "/dataset"
    
    DIF_SCHEMA_URI = "http://gcmd.nasa.gov/Aboutus/xml/dif/dif.xsd"

    JSON_SCHEMA_URI = "http://api.npolar.no/schema/dataset"

    SCHEMA_URI = {
      "dif" =>  DIF_SCHEMA_URI,
      "json" => JSON_SCHEMA_URI,
      "xml" => DIF_SCHEMA_URI
    }

    JSON_SCHEMAS = ["dataset.json"]

    class << self
      attr_accessor :formats, :accepts, :base
    end

    def self.facets
      [ "topics", "iso_topics", "sets", "relations", "licences", "draft",
        "investigators", "institutions", "project", "category", "schemas", "placename",
        "country_code", "progress", "editors", "rights"]
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
        raise ArgumentError, "Unknown schema format #{format}"
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
      "Dataset metadata in DIF XML, targeted at NASA's Global Change Master Directory."
    end

    def self.title
      "Norwegian Polar Institute's datasets"
    end
    
    # Map to Solr core "api"
    def to_solr
      doc = self

      id = doc["id"] ||=  doc["_id"]
      rev = doc["rev"] ||=  doc["_rev"] ||= nil

      solr = Hashie::Mash.new({ :id => id,
        :rev => rev,
        :title => title,
        :topics => topics,
        :tags => tags,
        :sets => sets,
        :iso_topics => doc["iso_topics"],
        :licences => doc["licenses"],
        :draft => doc["draft"],
        :workspace => "metadata",
        :collection => "dataset",
        :links => links,
        :licences => licences,
        :rights => rights,
        :institutions => contributors.map {|i|i.email.split("@")[1]}.uniq,
        :progress => doc.progress,
        :formats => self.class.formats,
        :accepts => self.class.accepts,
        :accept_mimetypes => self.class.mimetypes,
        :accept_schemas => self.class.schemas,
        :relations => [],
        :category => [],
        :schemas => self.class.schemas,
        :label => []
      })

        if doc.placenames?
          solr.country = doc.placenames.map {|p| p["country"]}.uniq.select {|c|c != ""}
        end

        if doc.science_keywords.respond_to? :map
          cat = []
          cat += doc["science_keywords"].map {|keyword| [keyword.Category ,keyword.Topic, keyword.Term, keyword.Variable_Level_1, keyword.Variable_Level_2, keyword.Variable_Level_3 ]}
          cat = cat.flatten.uniq
          solr[:category] = cat
        end

        if category?
          solr[:category] += doc["category"].map {|c| c["term"] }
          solr[:schemas] += doc["category"].map {|c| c["schema"] }
          solr[:label] +=  doc["category"].map {|c| c["label"] }
        end
          solr[:iso_topics] = doc["iso_topics"] #.select {|c| c["schema"] == "http://www.isotc211.org/2005/resources/Codelist/gmxCodelists.xml#MD_TopicCategoryCode"}.map {|c| c["term"] }

        if doc.key? "investigators"
          solr[:investigators] = doc["investigators"].map {|i| "#{i["first_name"]} #{i["last_name"]}"}
          solr[:investigator_emails] = doc["investigators"].select {|i|i.email?}.map {|i| "#{i["email"]}"}
        end
        
        if doc.key? "contributors"
          solr[:contributors] = doc["contributors"].map {|i| "#{i["first_name"]} #{i["last_name"]}"}
          solr[:contributor_emails] = doc["contributors"].select {|i|i.email?}.map {|i| "#{i["email"]}"}
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

      text = ""
      self.to_hash.each do |k,v|
         text += "#{k} = #{v} | "
      end
      solr[:text] = text

      solr[:link_edit] = "#{BASE.gsub(/\/$/, "")}/#{id}.json"
      solr[:link_html] = "http://data.npolar.no/dataset/#{id}"
      solr[:link_dif] = "/dataset/#{id}.dif"
      solr[:link_iso] = "/dataset/#{id}.iso"

      solr[:published] = doc.updated
      solr[:updated] = doc.updated

      solr

    end
    
    def from_dif
    end
    
    def to_dif
        t = Metadata::DifTransformer.new( self)
        dif_json = t.to_dif
        builder = ::Gcmd::DifBuilder.new( dif_json )
        xml = builder.build_dif
        if xml =~ /^\<\?xml\sversion=\"1.0\" encoding=\"UTF-8\"\?\>/
          xml = xml.split('<?xml version="1.0" encoding="UTF-8"?>')[1]
        end
        xml
    end

    def to_oai_dc
      xml = Builder::XmlMarkup.new
      xml.tag!("oai_dc:dc",
        'xmlns:oai_dc' => "http://www.openarchives.org/OAI/2.0/oai_dc/",
        'xmlns:dc' => "http://purl.org/dc/elements/1.1/",
        'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
        'xsi:schemaLocation' =>
          %{http://www.openarchives.org/OAI/2.0/oai_dc/
            http://www.openarchives.org/OAI/2.0/oai_dc.xsd}) do
          xml.tag!('oai_dc:title', title)
          xml.tag!('oai_dc:description', summary)
          xml.tag!('oai_dc:creator', investigators.map {|i| i.first_name + " " + i.last_name}.join(", "))
          tags.each do |tag|
            xml.tag!('oai_dc:subject', tag)
          end
      end
      xml.target!
    end
    
    def uri(id)
      self.class.uri + id
    end
    
    def schemas
      JSON_SCHEMAS
    end

    def errors
      @errors ||= nil
    end
    
  end
  
end
