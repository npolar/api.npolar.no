#encoding: utf-8

require "hashie"
require "uuidtools"
require "gcmd"

module Metadata
  # Dataset Transformer for DIF Documents.
  #
  # [Functionality]
  #   * Converts DIF into Norwegian Polar Data's dataset (schema)
  #   * Exports a metadata dataset to DIF.
  #
  # [Licence]
  #   This code is licenced under the {http://www.gnu.org/licenses/gpl.html GNU General Public Licence Version 3} (GPLv3)
  #
  # @author Ruben Dens
  # @author Conrad Helgeland
  
  class DifTransformer
    include ::Npolar::Api

    BASE = "http://api.npolar.no/dataset/"

    def self.dif_hash_array(xml_or_file)
        if File.exists? xml_or_file
          xml = File.read(xml_or_file)
        else
          xml = xml_or_file
        end

        j = []
        builder = ::Gcmd::HashBuilder.new( xml )
        difs = builder.build_hash_documents
       
        difs.each do | dif_hash |
          transformer = ::Metadata::DifTransformer.new( dif_hash )
          dataset = transformer.to_dataset
          j << dataset
        end
        j
    end

    def self.dif_hash(xml)
      self.dif_hash_array(xml)[0]
    end

    # base = base URI, see #href
    attr_accessor :base, :object
    alias :dif :object
    alias :dataset :object

    ISO8601_DATETIME_REGEX = /^(\d{4})-(0[1-9]|1[0-2])-([12]\d|0[1-9]|3[01])T([01]\d|2[0-3]):([0-5]\d):([0-5]\d)Z$/

    DATASET = [
      # atom
      :id, :title, :category, :links, :summary, :published, :updated, :draft, :source,
      # api
      :schema,
      # metadata 
      :topics, :coverage, :progress, :investigators, :contributors, :activity, :placenames,
      :quality, :science_keywords, :editors, :sets, :comment
    ]
    
    DIF_MAP = {
      :entry_id => "Entry_ID",
      :entry_title => "Entry_Title",
      :dataset_citation => "Data_Set_Citation",
      :summary_abstract => "Summary",
      :personnel => "Personnel",
      :spatial_coverage => "Spatial_Coverage",
      :dif_location => "Location",
      :temporal_coverage => "Temporal_Coverage",
      :iso_topic_category => "ISO_Topic_Category",
      :keyword => "Keyword",
      :related_url => "Related_URL",
      :reference => "Reference",
      :data_center => "Data_Center",
      :parameters => "Parameters",
      :idn_node => "IDN_Node",
      :parent_dif => "Parent_DIF",
      :data_quality => "Quality",
      :use_constraints => "Use_Constraints",
      :dataset_progress => "Data_Set_Progress",
      :creation_date => "DIF_Creation_Date",
      :revision_date => "Last_DIF_Revision_Date",
      :metadata_name => "Metadata_Name",
      :metadata_version => "Metadata_Version",
      :private => "Private"
    }
    #!? Originating_Metadata_Node
    # extra metadata => topics
    
    def initialize( object = {} )
      @base = BASE
      if object.is_a? Hash
        self.object = Hashie::Mash.new( object )
      else
        raise ArgumentError, "Expecting a Hash object!"
      end
    end
    
    # DIF => dataset (http://data.npolar.no/schema/dataset)
    def to_dataset
      dataset = Hashie::Mash.new
      # Loop equivalent of dataset.temporal_coverage = temporal_coverage
      DATASET.each do |method|
        dataset.send( method.to_s + '=', self.send( method ) )
      end
      
      dataset
    end

    def link(href, rel="related", title="", type="text/html")
      {
          "rel" => rel,
          "href" => href,
          "type" => type,
          "title" => title
      }
    end

    def comment
      object.comment ||= object.Entry_ID
    end

    def href(id, format="json")
      "#{base.gsub(/\/$/, "")}/#{id}.#{format}"
    end

    def id
      if object.Entry_ID =~ /^org[.|-]polarresearch\-/
        uuid(href(object.Entry_ID).gsub(/\.json$/, ""))
      else
        # hmm
        object.Entry_ID
      end
    end
    
    def title
      object.Entry_Title
    end

    def licences
      ["NLOD"]
    end
    
    def category
      c = dif.Keyword.nil? ? [] : object.Keyword.map {|k| {:term => k } }

      unless object.ISO_Topic_Category.nil?
        c += object.ISO_Topic_Category.map {|i| {:term => i, :schema => "http://www.isotc211.org/2005/resources/Codelist/gmxCodelists.xml#MD_TopicCategoryCode" } }
      end

      unless object.IDN_Node.nil?
        c += object.IDN_Node.map {|n| { :term => n["Short_Name"], :schema => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/dif.xsd#IDN_Node"} }
      end

      unless object.Project.nil?
        c += object.Project.map {|p| { :term => p["Short_Name"], :schema => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/dif.xsd#Project"} }
      end

      unless dif.Originating_Metadata_Node.nil?
        c += [{:term => dif.Originating_Metadata_Node, :schema => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/dif.xsd#Originating_Metadata_Node"}]
      end


      c
    end

    def topics
      guess_topics
    end
    
    def iso_topics
      #if !object.ISO_Topic_Category.nil? && object.ISO_Topic_Category.any?
      #  categories = object.ISO_Topic_Category.map{ |c| c.downcase }
      #end
    end

    def quality
      object.Quality
    end
    
    def published
      date = object.DIF_Creation_Date ||= Date.new(-1).xmlschema
      date += "T12:00:00Z" unless date == "" or date =~ ISO8601_DATETIME_REGEX
      date
    end

    def schema
      ::Metadata::Dataset::JSON_SCHEMA_URI
    end
    
    def updated
      date = object.Last_DIF_Revision_Date ||= Date.new(0).xmlschema
      date += "T12:00:00Z" unless date == "" or date =~ ISO8601_DATETIME_REGEX
      date
    end
    
    def progress
      case object.Data_Set_Progress
        when nil, "", "Complete" then "complete"
        when "In Work" then "ongoing"
        when "Planned" then "planned"
      end
    end
    
    def activity
      periods = []
      object.Temporal_Coverage.each do | period |
        
        start = ""
        start = period.Start_Date unless period.Start_Date.nil?
        start += "T12:00:00Z" unless start == "" or start =~ ISO8601_DATETIME_REGEX
        
        stop = ""
        stop = period.Stop_Date unless period.Stop_Date.nil?
        stop += "T12:00:00Z" unless stop == "" or stop =~ ISO8601_DATETIME_REGEX
        
        periods << Hashie::Mash.new({"start" => start, "stop" => stop})
      end unless object.Temporal_Coverage.nil?
      periods
    end
    
    def summary
      unless object.Summary.nil?
        unless object.Summary.is_a?( String )
          return object.Summary.Abstract unless object.Summary.Abstract.nil?
        else
          return object.Summary
        end
      else
        ""
      end
    end
    
    def investigators
      role_handler( "Investigator" )
    end
    
    def editors
      editor = role_handler( "DIF Author" )
      editor[0].edited = updated unless editor[0].nil?
      editor
    end
    
    def contributors
      contributors = role_handler( "Technical Contact" )
      contributors = ( contributors | investigators ) - ( investigators ) if contributors.any?
      contributors
    end
    
    def role_handler( role )
      contributors = []
      
      if ["Investigator", "DIF Author", "Technical Contact"].include?( role )
        object.Personnel.each do | person |
          
          first_name = ""
          first_name += person.First_Name unless person.First_Name.nil?
          first_name += " " + person.Middle_Name unless person.Middle_Name.nil? or person.Middle_Name == ""
          
          if person.Role.include?( role )
            contributors << Hashie::Mash.new( {
              "first_name" => first_name,
              "last_name" => person.Last_Name,
              "email" => person.Email.nil? ? "" : person.Email[0]
            } )
          end unless person.Role.nil?
        end unless object.Personnel.nil?
      else
        raise ArgumentError, "unknown DIF role!"
      end
      
      contributors
    end
    
    def placenames
      location_data = []

      object.Location.each do | location |
         
          location_data << Hashie::Mash.new({
            "placename" => location.Detailed_Location,
            "country_code" => guess_country_code_from_location(location),
          }) unless location.Detailed_Location.nil?
      end unless object.Location.nil?

      #if location_data.select {|l| !l["country_code"].nil? }.size == 0
      #  location_data = location_data.map {|l|
      #    l["country_code"] = guess_country_code_from_summary(summary)
      #    l
      #  }
      #end

      
      location_data
    end


    
    def coverage
      return [] if object.Spatial_Coverage.nil?

      object.Spatial_Coverage.map {|sc|
        Hashie::Mash.new({
          "north" => sc.Northernmost_Latitude.to_f,
          "east" => sc.Easternmost_Longitude.to_f,
          "south" => sc.Southernmost_Latitude.to_f,
          "west" => sc.Westernmost_Longitude.to_f,
        })
      }


    end
    
    def links
      links = []
      
      object.Related_URL.each do | link |
        type = link["URL_Content_Type"]["Type"] unless link.nil? or link["URL_Content_Type"].nil?
        
        unless type.nil?
          
          case( type )
          when "GET DATA" then type = "data"
          when "VIEW PROJECT HOME PAGE" then type = "project"
          when "VIEW EXTENDED METADATA" then type = "metadata"
          when "GET SERVICE" then type = "service"
          else type = "related"
          end
          
          link.URL.each do | url |
            if url =~ /^http:\/\/.*/
              links << {
                "rel" => type,
                "href" => url
              }
            end
          end unless link.URL.nil?
          
        end
        
      end unless object.Related_URL.nil? or !object.Related_URL.any?
      
      # Link to parent metadata records
      unless object.Parent_DIF.nil? 
      
      
        object.Parent_DIF.each do | parent |
          if parent =~ /\s+ /
          
            links << {
              "rel" => "parent",
              "href" => href(parent)
            }
          end 
        end
      end
      
      # Link to data centre
      
      object.Data_Center.each do |datacenter|
        
        url = ""        
        url = datacenter["Data_Center_URL"] unless datacenter["Data_Center_URL"].nil?        
        url = "http://data.npolar.no" if url == "http://www.npolar.no"
        if url =~ /data\.npolar\.no/
          title = "Norwegian Polar Data"
        end
        
        links << {
          "rel" => "datacenter",
          "href" => url,
        } unless url == ""
        
      end unless object.Data_Center.nil?
      
      # Remove related if it's to data.npolar.no
      links = links.select {|l|
      if l["href"] =~ /data\.npolar\.no(\/)?$/
        if l["rel"] =~ /related$/
          false
        else
          true
        end 
      else
        true
      end
      }

      if id =~ /http\:\/\//
        uri = id  
      else
        uri = href(id, "json")
      end
      

      links << link(uri, "edit", nil, "application/json")
      links << link(href(id, "dif"), "alternate", "DIF XML", "application/xml")
      links << link(href(id, "iso"), "alternate", "ISO 19139 XML", "application/vnd.iso.19139+xml")
      links << link(href(id, "atom"), "alternate", "Atom XML", "application/atom+xml")
      links << link("http://data.npolar.no/dataset/#{id}", "alternate", "HTML", "text/html")


      unless dif.Project.nil?
        projects = Gcmd::Concepts.new.tuples("projects")

        links += dif.Project.map {|p|
          id, label = projects.select { |tup | tup[1] == p["Short_Name"]}[0]
          unless id.nil?
            link("/gcmd/concept/#{id}.json", "project", label, "application/json")
          else
            link("/gcmd/concept/?q=#{label}&title=false&fields=*&format=json", "project", label, "application/json")
          end
          
        }
      end

      links
    end

    def rights
      dif.Use_Constraints +"\n"+dif.Access_Constraints
    end
    
    def sets
      sets = []
      
      object.IDN_Node.each do | node |
        
        case( node["Short_Name"] )
        when "IPY" then sets << "IPY"
        when "DOKIPY" then sets << "DOKIPY"
        when /^ARCTIC\/?.*/ then sets << "arctic"
        when /^AMD\/?.*/ then sets << "antarctic"
        end
        
      end unless object.IDN_Node.nil? or !object.IDN_Node.any?
      
      sets.uniq
    end
    
    def science_keywords
      object.Parameters ||= []
    end
    
    def draft
      draft = "no"
      if object.Private == "True"
        draft = "yes"
      else
        # Set to draft if NOT npolar or ipy
        if object.Entry_ID =~ /polarresearch/ and object.to_s !~ /(npolar|Norwegian Polar Institute|Norsk Polarinstitutt|Owned by NPI|IPY|DOKIPY)/
          draft = "yes"
        end
        
      end
      draft
    end
    
    def source
      Hashie::Mash.new( { :type => ::Gcmd::Dif::NAMESPACE["dif"], :data => object } )
    end    
    
    #################################
    ###### To GCMD DIF Format #######
    #################################
    
    def to_dif
      dif = Hashie::Mash.new
      
      # Loop equivalent of dataset.temporal_coverage = temporal_coverage
      DIF_MAP.each do |method, label|
        dif.send( label + '=', self.send( method ) )
      end
      
      dif
    end
    
    def entry_id
      object._id unless object._id.nil?
    end
    
    def entry_title
      object.title unless object.title.nil?
    end
    
    def summary_abstract
      { "Abstract" => object.summary }
    end
    
    def personnel
      personnel = []
      
      object.investigators.each do | investigator |
        
        contact_address = {}
        
        unless investigator.email.nil?

          if investigator.email.split("@")[1] == "npolar.no"
            contact_address = {
              "Address" => ["Norwegian Polar Institute"],
              "City" => "Tromsø",
              "Province_or_State" => "Troms",
              "Postal_Code" => "9296",
              "Country" => "Norway"
            }
          end
        end
      
        
        personnel << {
          "First_Name" => investigator.first_name.split(" ")[0],
          "Middle_Name" => investigator.first_name.split(" ")[1],
          "Last_Name" => investigator.last_name,
          "Email" => investigator.email,
          "Role" => ["Investigator"],
          "Contact_Address" => contact_address
        }
      end unless object.investigators.nil?
      
      personnel
    end
    
    def dataset_citation
      citation = []

      citation << {
        "Dataset_Creator" => dataset_creator,
        "Dataset_Title" => object.title
      }
      
      citation
    end
    
    def dataset_creator
      creator = ""
      
      object.investigators.each_with_index do |investigator, i|
        creator += "#{investigator["first_name"][0,1]}. #{investigator["last_name"]}"
        creator += ", " unless i == object.investigators.size - 1
      end unless object.investigators.nil? || !object.investigators.any?
      
      creator
    end
    
    def spatial_coverage
      coords = []
      
      object.locations.each do | loc |
        if loc.north || loc.east || loc.south || loc.west
          
          north = south = east = west = ""
          
          north = loc.north.to_s unless loc.north.nil?
          east = loc.east.to_s unless loc.east.nil?
          south = loc.south.to_s unless loc.south.nil?
          west = loc.west.to_s unless loc.west.nil?
          
          coords << {
            "Northernmost_Latitude" => north,
            "Easternmost_Longitude" => east,
            "Southernmost_Latitude" => south,
            "Westernmost_Longitude" => west,
          }
          
        end
        
      end unless object.locations.nil?
      
      coords
    end
    
    def dif_location
      locations = []
      
      object.locations.each do | loc |
        if loc.placename || loc.area || loc.country_code
          
          area = loc.area.downcase unless loc.area.nil?
          detailed_location = loc.placename unless loc.placename.nil?
          polar_region = {"Location_Category" => "GEOGRAPHIC REGION", "Location_Type" => "POLAR"}
          

          

          case( area )

          # set ARCTIC from sets
          #when "arctic" then
          #  locations << {
          #    "Location_Category" => "GEOGRAPHIC REGION",
          #    "Location_Type" => "ARCTIC",
          #    "Detailed_Location" => detailed_location
          #  }
          #  locations << polar_region
          when /^(Svalbard|Jan Mayen)$/ then
            locations << {
              "Location_Category" => "OCEAN",
              "Location_Type" => "ATLANTIC OCEAN",
              "Location_Subregion1" => "NORTH ATLANTIC OCEAN",
              "Location_Subregion2" => "SVALBARD AND JAN MAYEN",
              "Detailed_Location" => detailed_location
            }
            locations << polar_region
            locations << {
              "Location_Category" => "GEOGRAPHIC REGION",
              "Location_Type" => "ARCTIC"
            }
          when "antarctic" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "ANTARCTICA",
              "Detailed_Location" => detailed_location
            }
            locations << polar_region
          when "dronning_maud_land" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "ANTARCTICA",
              "Detailed_Location" => location_with_area(detailed_location, "Dronning Maud Land")
            }
            locations << polar_region
          when "bouvetøya" then
            locations << {
              "Location_Category" => "OCEAN",
              "Location_Type" => "ATLANTIC OCEAN",
              "Location_Subregion1" => "SOUTH ATLANTIC OCEAN",
              "Location_Subregion2" => "BOUVET ISLAND",
              "Detailed_Location" => detailed_location
            }
            locations << polar_region
          when "peter_i_øy" then
            locations << {
              "Location_Category" => "OCEAN",
              "Location_Type" => "PACIFIC OCEAN",
              "Location_Subregion1" => "SOUTH PACIFIC OCEAN",
              "Detailed_Location" => location_with_area(detailed_location, "Peter I Øy")
            }
            locations << polar_region
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "ANTARCTICA",
              "Detailed_Location" => nil
            }
          when "norway" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "EUROPE",
              "Location_Subregion1" => "NORTHERN EUROPE",
              "Location_Subregion2" => "SCANDINAVIA",
              "Location_Subregion3" => "NORWAY",
              "Detailed_Location" => detailed_location
            }
          when "russia" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "EUROPE",
              "Location_Subregion1" => "EASTERN EUROPE",
              "Location_Subregion2" => "RUSSIA",
              "Detailed_Location" => detailed_location
            }
          when "sweden" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "EUROPE",
              "Location_Subregion1" => "NORTHERN EUROPE",
              "Location_Subregion2" => "SCANDINAVIA",
              "Location_Subregion3" => "SWEDEN",
              "Detailed_Location" => detailed_location
            }
          when "canada" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "NORTH AMERICA",
              "Location_Subregion1" => "CANADA",
              "Detailed_Location" => detailed_location
            }
          when "greenland" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "NORTH AMERICA",
              "Location_Subregion1" => "GREENLAND",
              "Detailed_Location" => detailed_location
            }
          when "finland" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "EUROPE",
              "Location_Subregion1" => "NORTHERN EUROPE",
              "Location_Subregion2" => "SCANDINAVIA",
              "Location_Subregion3" => "FINLAND",
              "Detailed_Location" => detailed_location
            }
          when "iceland" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "EUROPE",
              "Location_Subregion1" => "NORTHERN EUROPE",
              "Location_Subregion2" => "ICELAND",
              "Detailed_Location" => detailed_location
            }
          when "united_states" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "NORTH AMERICA",
              "Location_Subregion1" => "UNITED STATES OF AMERICA",
              "Detailed_Location" => detailed_location
            }
          else
            locations << {
              "Location_Category" => "GEOGRAPHIC REGION",
              "Detailed_Location" => detailed_location
            } unless detailed_location.nil? || detailed_location == ""
          end
          
        end
      end unless object.locations.nil?
      
      locations.uniq
    end
    
    def location_with_area(location, area)
      if location.nil?
        area
      else
        "#{location} (#{area})"
      end
    end
    
    def temporal_coverage
      coverage = []
      
      object.activity.each do | act |
        
        start = act.start unless act.start.nil?
        stop = act.stop unless act.stop.nil?
        
        coverage << {
          "Start_Date" => start,
          "Stop_Date" => stop
        }
        
      end unless object.activity.nil?
      
      coverage
    end
    
    def use_constraints
      constraints = ""      
      object.licences.each_with_index do |licence, i|
        constraints += licence
        constraints += ", " unless (object.licences.size - 1) == i
      end unless object.licences.nil?
      
      constraints
    end
    
    def iso_topic_category
      categories = []
      
      categories = object.iso_topics.map{ |t| t.upcase} unless object.iso_topics.nil?
      
      categories
    end
    
    def keyword
      object.tags unless object.tags.nil?
    end
    
    def related_url
      urls = []
      
      object.links.each do |link|
        
        type = link["rel"] unless link["rel"].nil?
        # FIXME DOI
        unless type =~ /reference|doi|internal/
        
          case( type )
          when "dataset" then type = "GET DATA"
          when "metadata" then type = "VIEW EXTENDED METADATA"
          when "project" then type = "VIEW PROJECT HOME PAGE"
          when "service" then type = "GET SERVICE"
          when "parent" then type = "GET RELATED METADATA RECORD (DIF)"
          when "edit", "alternate" then type = nil

          else
            type = "VIEW RELATED INFORMATION" 
          end
          
          if type.nil?
            if link["href"] =~ /\.(iso|xml|json)$/
              type = "VIEW RELATED INFORMATION"
            end
            
          end
          
        # links to datacenter => Online_Resource?
          
          urls << {
            "URL_Content_Type" => {
              "Type" => type
            },
            "URL" => [link["href"]]
          }
        
        end
        
      end unless object.links.nil?
      
      urls
    end
    
    def reference
      reference = []
      
      object.links.each do |link|
        
        type = link["rel"] unless link["rel"].nil?
        
        case( type )
        when "doi" then reference << {"DOI" => link["href"]}
        when "reference" then reference << {"Online_Resource" => link["href"]}
        end
        
      end unless object.links.nil?
      
      reference
    end
    
    def data_center
      datacenter = []
      
      object.links.each do |link|
        link.each do |k,v|
          if k == "rel" and v == "datacenter"
            if link["href"] =~ /data\.npolar\.no/
              datacenter << {
                "Data_Center_Name" => {
                  "Short_Name" => "NO/NPI",
                  "Long_Name" => "Norwegian Polar Data" 
                },
                "Data_Center_URL" => "http://data.npolar.no/"
              }
            else
              datacenter << {
                "Data_Center_URL" => link["href"]
              } 
            end unless link["href"].nil?
          end
        end        
      end unless object.links.nil?
      
      datacenter
    end
    
    def parameters
      return [] if object.Parameters.nil?
      object.Parameters
    end
    
    # FIXME */no !?
    def idn_node
      nodes = []
      
      object.sets.each do |set|
        case( set )
        when "IPY" then nodes << {"Short_Name" => "IPY"}
        when "DOKIPY" then nodes << {"Short_Name" => "DOKIPY"}
        when "arctic" then nodes << {"Short_Name" => "ARCTIC"}
        when "antarctic" then nodes << {"Short_Name" => "AMD"}
        end
      end unless object.sets.nil?
      
      nodes.uniq
    end
    
    def parent_dif
      parents = []
      
      object.links.each do |link|
        link.each do |k ,v|
          if k == "rel" and v == "parent"
            parents << link["href"]
          end
        end
      end unless object.links.nil?
      
      parents
    end
    
    def data_quality
      object.quality unless object.quality.nil?
    end
    
    def dataset_progress
      prog = ""
      unless object.progress.nil?
        if object.progress == "ongoing"
          prog = "In Work"
        else
          prog = object.progress.capitalize
        end
      end
      
      prog
    end
    
    def creation_date
      object.published.split("T")[0]
    end
    
    def revision_date
      object.updated.split("T")[0]
    end
    
    def metadata_name
      "CEOS IDN DIF"
    end
    
    def metadata_version
      Gcmd::Schema::VERSION
    end
    
    def private
      "False"
    end
    
    def guess_country_code_from_location(location)
      if location.Location_Subregion2 =~ /SVALBARD AND JAN MAYEN/i
        "NO"
      elsif location.Location_Subregion2  =~ /Norway/i
        "NO"
      elsif location.Location_Subregion2  =~ /Russia/i
        "RU"
      elsif location.Location_Subregion2  =~ /Canada/i
        "CA"
      elsif location.Location_Type =~ /Antarctica/i
        "AQ"
      elsif location.Location_Subregion2  =~ /Antarctica/i
        "AQ"
      elsif location.Detailed_Location =~ /Dronning Maud Land/i
        "AQ"
      elsif location.Location_Subregion2  =~ /Greenland/i
        "GL"
      else
       nil
      end
    end

    def guess_country_code_from_summary(summary)

      if summary =~ /russia/i
        "RU"
      end
      
    end

    # Guess country code from sc
    # {"Southernmost_Latitude":"-90.0","Northernmost_Latitude":"-70.0","Westernmost_Longitude":"-20.0","Easternmost_Longitude":"54.0","Minimum_Altitude":"","Maximum_Altitude":"","Minimum_Depth":"","Maximum_Depth":""}
    def guess_country_code_from_spatial_coverage(scov)
      if scov.Northernmost_Latitude.to_f < -60.0
        "AQ"
      end
    end

    # See #topic
    # Intended use is getting at least one topic from legacy DIF XMLs imported from RiS.
    def guess_topics
      topics = []
      topics = parameters.map {|p| guess_topic_from_parameter(p)}
      if topics.none?
        topics = category.map {|c| guess_topic_from_category(c)}
      end
      if topics.none?
        topics << guess_topic_from_title(title)
      end
      if topics.none?
        topics << guess_topic_from_summary(summary)
      end
      
      topics.flatten.uniq.select {|t| t != nil and t != "" }
    end

    def guess_topic_from_parameter(parameter)
      if parameter.Variable_Level_1 =~ /FISHERIES/i
        "biology"
      elsif parameter.Term =~ /VEGETATION/i
        "biology"

      elsif parameter.Term =~ /ECOLOGICAL DYNAMICS|ECOSYSTEMS/i
        "biology"
      elsif parameter.Term =~ /ANIMALS\/VERTEBRATES/i
        "biology"

      elsif parameter.Variable_Level_1 =~ /CONTAMINANTS/i
        "ecotoxicology"

      elsif parameter.Term == "ROCKS/MINERALS"
        "geology"

      elsif parameter.Term == "GLACIERS/ICE SHEETS"
        "glaciology"

      elsif parameter.Term == /BOUNDARIES/i
        "maps"

      elsif parameter.Term =~ /OCEAN (TEMPERATURE|PRESSURE|SALINITY)/
        "oceanography"

      elsif parameter.Term =~ /SEA ICE/
        "seaice"

      elsif parameter.Term =~ /RADIATION/
        "geophysics"
      end
    end

    def guess_topic_from_category(category)
      if category =~ /(Persistent organic pollutants|POPs)/
        "ecotoxicology"
      end
    end

    def guess_topic_from_title(title)
      if title =~ /geology|geological/i
        "geology"
      elsif title =~ /bird|reindeer|fauna|ecology|faeces|fox|seal|walrus|vegetation|population dynamics|lichen/i
        "biology"
      elsif title =~ /radiation|spectral|meteorological|aerosol|ozone/i
        "geophysics"
      elsif title =~ /sea ice|fast ice|iceberg/i
        "seaice"
      elsif title =~ /snow/i
        "glaciology"
      else
        nil
      end
    end

    def guess_topic_from_summary(summary)
      if summary =~ /geologists|geological|sediment/i
        "geology"
      elsif summary =~ /glacier/i
        "glaciology"
      else
        nil
      end
    end

#glaciers =>
#GLACIERS (Science Keywords > EARTH SCIENCE > CRYOSPHERE > GLACIERS/ICE SHEETS) | concept 
#GLACIERS (Science Keywords > EARTH SCIENCE > TERRESTRIAL HYDROSPHERE > GLACIERS/ICE SHEETS) | concept 
  end
  
end
