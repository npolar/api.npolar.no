#encoding: utf-8

require "hashie"
require "uuidtools"
require "gcmd"

module Metadata
  # DIF <-> http://api.npolar.no/schema/dataset.json
  #
  # [Licence]
  # {http://www.gnu.org/licenses/gpl.html GNU General Public Licence Version 3} (GPLv3)
  #
  # @author Ruben Dens
  # @author Conrad Helgeland
  
  class DifTransformer
    include ::Npolar::Api

    BASE = "/dataset/"

    ROLE_MAP = {"TECHNICAL CONTACT" => "processor",
      "INVESTIGATOR" => "principalInvestigator",
      "DATA CENTER CONTACT" => "pointOfContact",
      "INVESTIGATOR  (PROJECT LEADER)" => "principalInvestigator"
    }

    def self.dif_hash_array(xml_or_file)
        if File.exists? xml_or_file
          xml = File.read(xml_or_file)
        else
          xml = xml_or_file
        end

        j = []
        builder = ::Gcmd::Dif.new( xml )
        difs = builder.document_to_array
       
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
      :id, :title, :category, :iso_topics, :links, :summary, :published, :updated, :draft, :source,
      # api
      :schema,
      # metadata 
      :topics, :coverage, :progress, :people, :organisations, :activity, :placenames,
      :quality, :gcmd, :edits, :sets, :comment, :rights
    ]

   
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

    def iso_topics
      if dif.ISO_Topic_Category? and dif.ISO_Topic_Category.respond_to?(:map)
        dif.ISO_Topic_Category.map {|i| normalize_iso_topics(i) }
      end
    end
    
    def category
      c = dif.Keyword.nil? ? [] : object.Keyword.map {|k| {:term => k } }

      #unless object.IDN_Node.nil?
      #  c += object.IDN_Node.map {|n| { :term => n["Short_Name"], :schema => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/dif.xsd#IDN_Node"} }
      #end

      #unless object.Project.nil?
      #  c += object.Project.map {|p| { :term => p["Short_Name"], :schema => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/dif.xsd#Project"} }
      #end

      #unless (dif.Originating_Metadata_Node.nil? or "" == dif.Originating_Metadata_Node)
      #  c += [{:term => dif.Originating_Metadata_Node, :schema => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/dif.xsd#Originating_Metadata_Node"}]
      #end
      c
    end

    def topics
      guess_topics
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
      contributors.select {|c| c.roles.include? "principalInvestigator" }
    end
    
    def edits
      [] #editor = contribut( "DIF Author" )
      #editor[0].edited = updated unless editor[0].nil?
      #editor
    end
    
    def people

      people = []
      if dif.Personnel? # It's not always there (for invalid documents)
        people += dif.Personnel.map { |p|
        self.class.contributor_from_personnel(p)
      }
      end
      if dif.Data_Center?
        dif.Data_Center.each do |dc|
          if dc.Personnel?
            people += dc.Personnel.map { |p|
              self.class.contributor_from_personnel(p)
          }
          end
          
        end
      end
      people
    end


    def organisations
      orgs = []
      if dif.Data_Center? 
        dif.Data_Center.select {|dc| dc.Data_Center_Name? }.each {|dc|          

          roles = ["owner"]
          name = dc.Data_Center_Name.Long_Name
          url = dc.Data_Center_URL.gsub(/^http:\/\/www./, "http://").gsub(/\/$/, "")

          if  dc.Data_Center_Name.Long_Name =~ /Norwegian Polar Institute/
            name = "Norwegian Polar Institute"
            url = "http://data.npolar.no"
            roles << "publisher"   
          end
          
          orgs << Hashie::Mash.new({
            "name" => name,
            "gcmd_short_name" => dc.Data_Center_Name.Short_Name,
            "roles" => roles,
            "uri" => url
          })      
        }
      end          
      orgs
    end
    
    def self.contributor_from_personnel(p)
      first_name = p.First_Name
      if p.Middle_Name? and p.Middle_Name.size >= 1
        first_name += " " + p.Middle_Name 
      end

      Hashie::Mash.new({
        "first_name" => first_name,
        "last_name" => p.Last_Name,
        "email" => p.Email.nil? ? "" : p.Email[0],
        "roles" => self.roles_from_dif_role(p.Role),
      })
    end

    def self.roles_from_dif_role( role )
      role.map {|r|
        ROLE_MAP.key?(r.upcase) ? ROLE_MAP[r.upcase] : role
      } 
    end
    
    def placenames
      
      (dif.Location||[]).select {|location| location.Detailed_Location?}.map {
        |location|
          Hashie::Mash.new({
            "placename" => location.Detailed_Location,
            "area" => area_from_location(location),
            "country_code" => guess_country_code_from_location(location),
        })
      }
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
    
    # Links from
    #  1. Related_URL
    #  2. Data_Set_Citation
    #
    def links
      links = []
      if dif.Entry_ID =~ /^(org[.|-]polarresearch\-)/
        via = "http://risapi.data.npolar.no/oai?verb=GetRecord&metadataPrefix=dif&identifier=oai:ris.npolar.no:#{dif.Entry_ID}"
        links << {
          "rel" => "via",
          "href" => via,
          "type" =>  "application/xml"
        }        
      end
            # "metadata"-html <-- DatasetDOI   
      # "related  " OnlineResource 

      # 1. Related_URL
      if dif.Related_URL?
      
      dif.Related_URL.each do | link |

        if link.URL_Content_Type? and link.URL_Content_Type.Type?
          dif_type = link.URL_Content_Type.Type
        else
          dif_type = ""
        end
 
        type = case dif_type
          when "GET DATA" then "data"
          when "VIEW PROJECT HOME PAGE" then "project"
          when "VIEW EXTENDED METADATA" then "metadata"
          when "GET SERVICE" then "service"
          when "VIEW RELATED INFORMATION" then "related"
          else dif_type
        end
         
        link.URL.each do | url |

          links << {
            "rel" => type,
            "href" => url,
            "title" => link.Description
          }  
        end  
      end
      end

      # Link to parent metadata records
      unless object.Parent_DIF.nil? 
      #raise object.Parent_DIF.to_json

        object.Parent_DIF.each do | parent |
          
            links << {
              "rel" => "parent",
              "href" => href(href(parent, "json")),
              # FIXME oops "href": "/dataset//dataset/org.polarresearch-494.json.json" http://localhost:9393/dataset/7298f0f5-3c7c-5d95-852b-f2eb7585af47.json
            }
           
        end
      end
      
      # Link to data centre
      
      
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

      if id =~ /^http\:\/\//
        uri = id  
      else
        uri = href(id, "json")
      end
      

      # Move to model!?
      links << link(uri, "edit", nil, "application/json")
      links << link(href(id, "dif"), "alternate", "DIF XML", "application/xml")
      links << link(href(id, "iso"), "alternate", "ISO 19139 XML", "application/vnd.iso.19139+xml")
      links << link(href(id, "atom"), "alternate", "Atom XML", "application/atom+xml")
      links << link("http://data.npolar.no/dataset/#{id}", "alternate", "HTML", "text/html")


      #unless dif.Project.nil?
      #  projects = Gcmd::Concepts.new.tuples("projects")
      #
      #  links += dif.Project.map {|p|
      #    id, label = projects.select { |tup | tup[1] == p["Short_Name"]}[0]
      #    unless id.nil?
      #      link("/gcmd/concept/#{id}.json", "project", label, "application/json")
      #    else
      #      [] #link("/gcmd/concept/?q=#{label}&title=false&fields=*&format=json", "project", label, "application/json")
      #    end
      #    
      #  }
      #end

      links
    end

    def rights
      rights = ""
      if dif.Use_Constraints?
        #rights += "Use constraints: #{dif.Use_Constraints}"
      end
      if dif.Access_Constraints?
        #rights += "\nAccess_Constraints: #{dif.Access_Constraints}"
      end
      rights
    end
    
    def sets
      sets = []
      
      dif.IDN_Node.each do | node |
        
        case( node["Short_Name"] )
          when "IPY" then sets += ["IPY", "GCMD"]
          when "DOKIPY" then sets << "DOKIPY"
          when /^ARCTIC\/?.*/ then sets << "arctic"
          when /^AMD\/?.*/ then sets << "antarctic"
        end
        
      end
      sets.uniq
    end
    
    def gcmd
      { "sciencekeywords" => dif.Parameters || [],
        "instruments" => dif.Sensor_Name || [],
        "platforms" => dif.Source_Name || []
        #"locations" => dif.Location || []
        # projects
        # disciplines
        #  temporalresolutionrange  horizontalresolutionrange verticalresolutionrange
        #chronounits
        #idnnode
      }
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
      #Hashie::Mash.new( { :type => ::Gcmd::Dif::NAMESPACE["dif"], :data => object } )
    end    
    
    def dataset_citation
      citation = []

      citation << {
        "Dataset_Creator" => dataset_creator,
        "Dataset_Title" => object.title,
        #"Dataset_Publisher" 
      }
      
      citation
    end
    
    def dataset_creator
      creator = ""
      
      investigators = object.contributors.select{|c|c.person != false and c.roles.include? "principalInvestigator"}
      creator = investigators.map {|investigator|
        "#{investigator.name} #{investigator.surname}"
      }.join(", ")
      creator
    end
    
    def spatial_coverage
      coords = []
      
      object.coverage.each do | loc |
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
        
      end
      
      coords
    end
    
    def dif_location
      locations = []
      
      object.placenames.each do | loc |
        if loc.placename || loc.country
          
          
          detailed_location = loc.placename unless loc.placename.nil?
          polar_region = {"Location_Category" => "GEOGRAPHIC REGION", "Location_Type" => "POLAR"}
          

          

          case( loc.placename )

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
          when "Antarctic" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "ANTARCTICA",
              "Detailed_Location" => detailed_location
            }
            locations << polar_region
          when "Dronning Maud Land" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "ANTARCTICA",
              "Detailed_Location" => location_with_area(detailed_location, "Dronning Maud Land")
            }
            locations << polar_region
          when "Bouvetøya" then
            locations << {
              "Location_Category" => "OCEAN",
              "Location_Type" => "ATLANTIC OCEAN",
              "Location_Subregion1" => "SOUTH ATLANTIC OCEAN",
              "Location_Subregion2" => "BOUVET ISLAND",
              "Detailed_Location" => detailed_location
            }
            locations << polar_region
          when "Peter I Øy" then
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
          when "Norway" then
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "EUROPE",
              "Location_Subregion1" => "NORTHERN EUROPE",
              "Location_Subregion2" => "SCANDINAVIA",
              "Location_Subregion3" => "NORWAY",
              "Detailed_Location" => detailed_location
            }
          when "Russia" then
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
      dataset.draft == "yes" ? "True" : "False"
    end
    
    protected

    def area_from_location(location)
      if location.Location_Subregion2 =~ /SVALBARD AND JAN MAYEN/i
        "Svalbard"
      else
        ""
      end

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

    # See #topics
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

    def normalize_iso_topics(dif_iso_topic)
      step1 = dif_iso_topic.downcase.gsub(/(\s|\/)/, "")
      iso_topic = case step1
        when "geoscientificinformation"
          "geoscientificInformation"
        when "climatologymeteorologyatmosphere"
          "climatologyMeteorologyAtmosphere"
        when "imagerybasemapsearthcover"
          "imageryBaseMapsEarthCover"
        when "inlandwaters"
          "inlandWaters"
        when "intelligencemilitary"
          "intelligenceMilitary"
        when "planningcadastre"
          "planningCadastre"
        when "utilitiescommunication"
          "utilitiesCommunication"
        else
          step1
      end
      unless ["biota", "boundaries", "climatologyMeteorologyAtmosphere", "economy",
        "elevation", "environment", "farming", "geoscientificInformation", "health",
        "imageryBaseMapsEarthCover", "inlandWaters", "intelligenceMilitary", "location",
        "oceans", "planningCadastre", "society", "structure", "transportation",
        "utilitiesCommunication"].include? iso_topic
        raise "Bad ISO Topic Category: \"#{iso_topic}\""
      end
      iso_topic

    end

#glaciers =>
#GLACIERS (Science Keywords > EARTH SCIENCE > CRYOSPHERE > GLACIERS/ICE SHEETS) | concept 
#GLACIERS (Science Keywords > EARTH SCIENCE > TERRESTRIAL HYDROSPHERE > GLACIERS/ICE SHEETS) | concept 
  end
  
end
