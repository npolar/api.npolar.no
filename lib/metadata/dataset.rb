require "hashie"

module Metadata

  # Npolar dataset (http://api.npolar.no/schema/dataset) model
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
  #
  # Open issues
  # * Setting and enforcing defaults
  # * Handling before_save

  # resourceProvider Data Center Contact
# npolar.no-dataset originator npolar.no
  
  class Dataset < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator

    BASE = "http://api.npolar.no/dataset/"
    
    DIF_SCHEMA_URI = "http://gcmd.nasa.gov/Aboutus/xml/dif/dif.xsd"

    JSON_SCHEMA_URI = "http://api.npolar.no/schema/dataset"

    SCHEMA_URI = {
      "dif" =>  DIF_SCHEMA_URI,
      "json" => JSON_SCHEMA_URI,
      "xml" => DIF_SCHEMA_URI
    }

    JSON_SCHEMAS = ["dataset.json"] # "minimal-dataset.json",

    class << self
      attr_accessor :formats, :accepts, :base
    end

    def self.licences
      ["http://data.norge.no/nlod/no/1.0",
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
        {:spec => "IPY", :name => "International Polar Year", :description => "Datasets from the International Polar Year (2007-2008)"},
        {:spec => "cryoclim.net", :name => "Cryoclim", :description => "Climate monitoring of the cryosphere, see http://cryoclim.net"},
        {:spec => "NMDC", :name => "Norwegian Marine Data Centre", :description => "Marine datasets"},
        {:spec => "GCMD", :name => "Global Change Master Directory" }
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
        :iso_topics => iso_topics,
        :licences => licences,
        :restricted => restricted,
        :restrictions => restrictions,
        :draft => draft,
        :workspace => "metadata",
        :collection => "dataset",
        :links => links,
        :rights => rights,
        :progress => progress,
        :formats => self.class.formats,
        :accepts => self.class.accepts,
        :accept_mimetypes => self.class.mimetypes,
        :accept_schemas => self.class.schemas,
        :relations => [],
        :category => [],
        :comment => comment,
        :schemas => self.class.schemas,
        :label => [],
        :people => (people||[]).map {|p| "#{p.first_name} #{p.last_name}"}
      })

        if placenames?
          solr.placename = placenames.map {|p| p.placename}.uniq.select {|p|p != ""}
          solr.area = placenames.map {|p| p.area}.uniq.select {|a|a != ""}
          solr.country = placenames.map {|p| p.country}.uniq.select {|c|c != ""}
        end

        if gcmd? and gcmd.sciencekeywords?
          cat = []
          cat += gcmd.sciencekeywords.map {|keyword| [keyword.Category, keyword.Topic, keyword.Term, keyword.Variable_Level_1, keyword.Variable_Level_2, keyword.Variable_Level_3 ]}
          cat = cat.flatten.uniq
          solr[:category] = cat
        end

        if category?
          solr[:category] += category.map {|c| c["term"] }
          solr[:schemas] += category.map {|c| c["schema"] }
          solr[:label] +=  category.map {|c| c["label"] }
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

      schema = ::Gcmd::Schema.new
      errors = schema.validate_xml( self.to_dif ).map {|e|e["details"].to_s.gsub(/["'\/\\()]/, "")}

      solr[:errors] = errors
      solr[:valid] = errors.any? ? false : true

      solr[:link_edit] = "/dataset/#{id}.json"
      solr[:link_html] = "http://data.npolar.no/dataset/#{id}"
      solr[:link_dif] = "/dataset/#{id}.dif"
      solr[:link_iso] = "/dataset/#{id}.iso"

      solr[:published] = published
      solr[:updated] = updated

      solr[:owners] = owners.map {|o|o.id}
# org roles => owner publisher resP



      solr

    end

    def owners
      (organisations||[]).select {|o| o.roles.include? "owner"}
    end

    def load_dif
    end
    
    def temporal_coverage
    end

    def to_dif_hash
      DifHashifier.new(self).to_hash
    end

    def pointOfContact
      (people||[]).select {|p| p.roles.include? "pointOfContact"} 
    end

    #def people(role=nil)
    #  
    #end



    def to_dif
        #t = Metadata::DifTransformer.new(self)
        builder = ::Gcmd::DifBuilder.new( to_dif_hash )
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

    def self.before_request
      lambda {|request|


    #def multiple_roles
    #  [lambda {|d|
    #    d.contributors? },
    #  lambda {|d|
    #    names = d.contributors.map {|c| c.name }.uniq
    #    
    #    d.contributors = names.map {|name|
    #      entity = d.contributors.select {|c| c.name == name }.first
    #
    #      uri = nil
    #      if name =~ /Norwegian Polar (Institute|Data)/
    #        uri = "http://npolar.no"
    #      end
    #
    #      { "name" => name,
    #        "roles" => d.contributors.select {|c| c.name == name }.map {|c| c.role }.uniq,
    #        "email" => entity.email,
    #        "person" => entity.person == false ? false : true,
    #        "surname" => entity.surname,
    #        "uri" => uri
    #      }
    #    }
    #    d
    #  }]
    #end

        # if POST, PUT - how about multi...

        dataset = Metadata::Dataset.new
        dataset = dataset.before_valid?(d)

      #links << link(uri, "edit", nil, "application/json")
      #links << link(href(id, "dif"), "alternate", "DIF XML", "application/xml")
      #links << link(href(id, "iso"), "alternate", "ISO 19139 XML", "application/vnd.iso.19139+xml")
      #links << link(href(id, "atom"), "alternate", "Atom XML", "application/atom+xml")
      #links << link("http://data.npolar.no/dataset/#{id}", "alternate", "HTML", "text/html")


#biology =>
#<Parameters>
#<Category>EARTH SCIENCE</Category>
#<Topic>BIOSPHERE</Topic>


      # Make sure we have at least 1 Data_Center (required)
      #if organisations.nil? or organisations.none?
      #  self[:organisations] = [{ "name" => "Norwegian Polar Institute",
      #    "id" => "npolar.no",
      #    "gcmd_short_name" => "NO/NPI",
      #    "roles" => ["publisher"], "links" => [{ "rel" => "publisher",
      #      "href" => "http://data.npolar.no",
      #      "title" => "Norwegian Polar Institute", "lang" => "en" }]}]
      #end

      # Make sure we have 1 Data Center Contact (pointOfContact)
      #if pointOfContact.none?
      #  self[:people] << {"last_name" => "Norwegian Polar Data Centre",
      #    "roles" => ["pointOfContact"], "email" => "data[*]npolar.no"}
      #end

    }
    end
    
    def before_valid

      if activity?      
        activity.map {|a|
          if a.start? and a.start == ""
            a.delete :start
          end
          if a.stop? and a.stop == ""
            a.delete :stop
          end
          a
        }
      end

      if coverage?
        coverage.map {|c|
          if c.north?
            c.north = c.north.to_f
          end
          if c.south?
            c.south = c.south.to_f
          end
          if c.east?
            c.east = c.east.to_f
          end
          if c.west?
            c.west = c.west.to_f
          end
        }
      end      
      self

    end

    def schemas
      JSON_SCHEMAS
    end
    
  end
  
end