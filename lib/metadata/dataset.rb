# encoding: utf-8
require "hashie"

module Metadata

  # Npolar dataset (http://api.npolar.no/schema/dataset) model
  #
  # [Features]
  #   * Extends Hashie::Mash for easy method access
  #   * Before and after save (POST/PUT) logic
  #   * Transform to Solr-style Hash (for creating Solr JSON)
  #   * Transform to DIF XML Hash (for creating DIF XML)
  #   * Validation based on JSON Schema
  #
  # [License]
  #   {http://www.gnu.org/licenses/gpl.html GNU General Public License Version 3} (GPLv3)
  #
  # @author Ruben Dens
  # @author Conrad Helgeland
  #
  # Open issues
  # * Setting and enforcing defaults (defined in schema)
  # * Defining defaults (originator? publisher?)
  class Dataset < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator
    
    BASE = "http://api.npolar.no/dataset/"
    
    DIF_SCHEMA_URI = "http://gcmd.nasa.gov/Aboutus/xml/dif/dif.xsd"

    JSON_SCHEMA_URI = "http://api.npolar.no/schema/dataset"

    JSON_SCHEMAS = ["dataset.json"]

    NPOLAR_NO = { id: "npolar.no",
      name: "Norwegian Polar Institute",
      gcmd_short_name: "NO/NPI",
      roles: ["originator", "owner", "publisher", "resourceProvider", "pointOfContact"],
      links: [ {rel: "owner", href: "http://npolar.no", title: "Norwegian Polar Institute" },
        {rel: "publisher", href: "http://data.npolar.no", title: "Norwegian Polar Institute" }
      ]
    }
    SCHEMA_URI = {
      "dif" =>  DIF_SCHEMA_URI,
      "json" => JSON_SCHEMA_URI,
      "xml" => DIF_SCHEMA_URI
    }

    class << self
      attr_accessor :formats, :accepts, :base
    end

    # Streamline incoming datasets before save
    # @return lambda
    # See Core#handle and Core#before
    def self.after
      lambda {|request,response|
        if request.post?
          Dataset.after_create(request,response)
        else
          response
        end
      }
    end

    # 
    # @return response Rack::Response
    def self.after_create(request,response)

      datasets = JSON.parse(response.body.join(""))
      datasets = datasets.is_a?(Hash) ? [datasets] : datasets
      
      datasets = datasets.map {|d|
        dataset = self.new(d)
        dataset = dataset.add_edit_and_alternate_links
        dataset
      }

      body = case datasets.size
        when 1
          datasets[0].to_json
        else
          datasets.to_json
      end
      response.body = StringIO.new(body) 
      response

    end

    # Process incoming dataset(s) before storage interaction
    # @return lambda
    # See Core#handle and Core#before
    def self.before
      lambda {|request|
        if request.put? or request.post?
          Dataset.before_save(request)
        else
          request
        end
      }
    end

    # Add default information to dataset(s) before saving
    # @return request
    def self.before_save(request)
      body = request.body.read
      datasets = JSON.parse(body)
      datasets = datasets.is_a?(Hash) ? [datasets] : datasets

      datasets = datasets.map {|d|

        dataset = self.new(d)
        dataset.collection = "dataset"

        if not dataset.lang?
          dataset.lang = "en"
        end
        
        if not dataset.title? or not dataset.topics? or not dataset.licences
          dataset.draft = "yes"
        end

        if not dataset.title?
          dataset.title = "Dataset created by #{request.username} at #{Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")}"
        end

        dataset = dataset.before_valid

        dataset = dataset.deduplicate_people

        dataset = dataset.add_edit_and_alternate_links
        
        if not dataset.licences? or dataset.licences.none?
          dataset.licences = licences
        end

        if not dataset.rights? or dataset.rights.nil? or dataset.rights == ""
          dataset.rights = rights(dataset)
        end

        if not dataset.organisations? or dataset.organisations.none?
          dataset.organisations = [NPOLAR_NO]
        end

        if not dataset.topics? or dataset.topics.none?
          dataset.topics = ["other"]
        end

        if not dataset.schema?
          dataset.schema = JSON_SCHEMA_URI
        end

        # add resourceProvider if link[rel=="data"]

        dataset
      }
  
      body = case datasets.size
        when 1
          datasets[0].to_json
        else
          datasets.to_json
      end

      request.body = body 
      request
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

    #def self.sets
    #  oai_sets.map {|set| set[:spec] }
    #end

    def self.rights(dataset=nil)
      nlod = /data.norge.no\/nlod/
      ccby = /creativecommons.org\/licenses\/by/
      odc = /opendatacommons.org\/licenses\/by/
      cc0 = /creativecommons.org\/publicdomain\/zero/
      åvl = /lovdata.no\/all\/(h|n)l-19610512-002/
      
      if dataset.licences.select {|l| l =~ cc0 }.size > 0
        "Dataset is in the public domain."
      elsif dataset.licences.select {|l| l =~ /#{nlod}|#{ccby}|#{odc}/ }.size > 0
        "Dataset is open data and free to reuse if you attribute the source.\nLicences: #{licences.join(" or ")}"
      elsif dataset.licences.select {|l| l =~ åvl }.size > 0
        "Dataset protected under \"Lov om opphavsrett til åndsverk m.v. (åndsverkloven)\".\n http://www.lovdata.no/all/hl-19610512-002.html"
      end
    end

    def self.schemas
      [schema_uri("json"), schema_uri("xml")]
    end

    def self.schema_uri(format="json")
      if SCHEMA_URI.key? format
        SCHEMA_URI[format]
      else
        raise ArgumentError, "Unknown schema format: \"#{format}\""
      end
    end

    #def self.oai_sets
    #  [ {:spec => "arctic", :name => "Arctic datasets"},
    #    {:spec => "antarctic", :name => "Antarctic datasets"},
    #    {:spec => "IPY", :name => "International Polar Year", :description => "Datasets from the International Polar Year (2007-2008)"},
    #    {:spec => "cryoclim.net", :name => "Cryoclim", :description => "Climate monitoring of the cryosphere, see http://cryoclim.net"},
    #    {:spec => "NMDC", :name => "Norwegian Marine Data Centre", :description => "Marine datasets"},
    #    {:spec => "GCMD", :name => "Global Change Master Directory" }
    #  ]
    #end

    #def self.summary
    #  "Dataset metadata in DIF XML, targeted at NASA's Global Change Master Directory."
    #end
    #
    #def self.title
    #  "Norwegian Polar Institute's datasets"
    #end
    
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

    def authors 
      (people||[]).select {|o| o.roles.include? "author" or  o.roles.include? "principalInvestigator" }
    end

    def owners
      (organisations||[]).select {|o| o.roles.include? "owner"}
    end

    def to_dif_hash
      DifHashifier.new(self).to_hash
    end

    def pointOfContact
      (people||[]+organisations||[]).select {|entity| entity.roles.include? "pointOfContact"} 
    end

    def to_dif
      dif = ::Gcmd::Dif.new( to_dif_hash )
      dif.to_xml
    end

    #def to_oai_dc
    #  xml = Builder::XmlMarkup.new
    #  xml.tag!("oai_dc:dc",
    #    'xmlns:oai_dc' => "http://www.openarchives.org/OAI/2.0/oai_dc/",
    #    'xmlns:dc' => "http://purl.org/dc/elements/1.1/",
    #    'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
    #    'xsi:schemaLocation' =>
    #      %{http://www.openarchives.org/OAI/2.0/oai_dc/
    #        http://www.openarchives.org/OAI/2.0/oai_dc.xsd}) do
    #      xml.tag!('oai_dc:title', title)
    #      xml.tag!('oai_dc:description', summary)
    #      xml.tag!('oai_dc:creator', investigators.map {|i| i.first_name + " " + i.last_name}.join(", "))
    #      tags.each do |tag|
    #        xml.tag!('oai_dc:subject', tag)
    #      end
    #  end
    #  xml.target!
    #end
    
    def uri(id)
      self.class.uri + id
    end

    def deduplicate_people
      unique_people = (people||[]).map {|p| [p.first_name, p.last_name]}.uniq
      self[:people] = unique_people.map {|first_name, last_name |
        persons = people.select {|p| first_name == p.first_name and last_name == p.last_name }
        person = persons[0]
        { "first_name" => first_name,
          "last_name" => last_name,
          "roles" => persons.map {|p| p.roles }.flatten.uniq,
          "email" => person.email,
          "organisation" => person.organisation
        }
      }
      self
    end

    def add_edit_and_alternate_links
      api = ENV["NPOLAR_API"] ||= "http://api.npolar.no"

      self[:links] = links||[] 

      if id? # => These links are not added on POST (see #after_save for a fix)
      
        # edit  ("application/json")
        if links.select {|link| link.rel=="edit" and link.type == "application/json"}.size == 0
          self[:links] << Hashie::Mash.new({ "href" => "#{api.gsub(/^http[:]/, "https:")}/dataset/#{id}",
            "rel" => "edit", "title" => "Edit URI", "type" => "application/json" })
        end
  
        # DIF XML
        if links.select {|link| link.rel=="alternate" and link.type == "application/xml"}.size == 0
          self[:links] << Hashie::Mash.new({ "href" => "#{api}/dataset/#{id}.xml",
            "rel" => "alternate", "title" => "DIF XML", "type" => "application/xml"})
        end
  
        # DIF XML
        if links.select {|link| link.rel=="alternate" and link.type == "application/vnd.iso.19139+xml"}.size == 0
          self[:links] << Hashie::Mash.new({ "href" => "#{api}/dataset/#{id}.iso",
            "rel" => "alternate", "title" => "ISO 19139 XML", "type" => "application/vnd.iso.19139+xml"})
        end
  
        # Atom XML
        if links.select {|link| link.rel=="alternate" and link.type == "application/atom+xml"}.size == 0
          self[:links] << Hashie::Mash.new({ "href" => "#{api}/dataset/#{id}.atom",
            "rel" => "alternate", "title" => "Atom entry XML", "type" => "application/atom+xml"})
        end
  
        # html
        if links.select {|link| link.rel=="alternate" and link.type == "text/html"}.size == 0
          self[:links] << Hashie::Mash.new({ "href" => "http://data.npolar.no/dataset/#{id}",
            "rel" => "alternate", "title" => "HTML", "type" => "text/html" })
        end
      end

      self

    end

    # Manipulates documents before validation
    # @override MultiJsonSchemaValidator
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

    # @override MultiJsonSchemaValidator
    def schemas
      JSON_SCHEMAS
    end
    
  end
  
end