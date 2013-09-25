#encoding: utf-8

require "hashie"
require "uuidtools"
require "uri"
require "gcmd"

module Metadata
  # DIF XML => http://api.npolar.no/schema/dataset.json
  #
  # [Licence]
  # {http://www.gnu.org/licenses/gpl.html GNU General Public Licence Version 3} (GPLv3)
  #
  # @author Ruben Dens
  # @author Conrad Helgeland
  class DifTransformer
    include ::Npolar::Api

    BASE = "http://api.npolar.no/dataset/"

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

    def self.person_from_personnel(p)

      first_name = p.First_Name
      if p.Middle_Name? and p.Middle_Name.size >= 1
        first_name += " " + p.Middle_Name 
      end

      email = p.Email.nil? ? "" : p.Email[0]
      organisation = email.split("@")[1]
      if organisation.nil?
        if p.Contact_Address? and p.Contact_Address.respond_to?(:Address) and p.Contact_Address.Address.any?
          if p.Contact_Address.Address.join("") =~ /Norwegian Polar Institute|Norsk Polarinstitutt/
            organisation = "npolar.no"
          else
            organisation = p.Contact_Address.Address[0]
          end
        end
        
      end

      Hashie::Mash.new({
        "first_name" => first_name,
        "last_name" => p.Last_Name,
        "email" => email,
        "roles" => self.roles_from_dif_role(p.Role),
        "organisation" => organisation
      })
    end

    def self.roles_from_dif_role( role )
      role.map {|r|
        ROLE_MAP.key?(r.upcase) ? ROLE_MAP[r.upcase] : role
      } 
    end

    # base = base URI, see #href
    attr_accessor :base, :object
    alias :dif :object
    alias :dataset :object

    ISO8601_DATETIME_REGEX = /^(\d{4})-(0[1-9]|1[0-2])-([12]\d|0[1-9]|3[01])T([01]\d|2[0-3]):([0-5]\d):([0-5]\d)Z$/

    DATASET = [
      # api
      :id, :schema, :collection, :topics, :iso_topics, :tags, :rights, :restricted, :restrictions, :licences,
      # atom
      :title, :links, :summary, :published, :updated, :draft,
      # metadata 
      :coverage, :progress, :people, :organisations, :activity, :placenames,
      :quality, :gcmd, :edits, :sets, :comment
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
      Hashie::Mash.new({
          "rel" => rel,
          "href" => href,
          "type" => type,
          "title" => title
      })
    end

    def comment
      comment = ""
      if dif.Entry_ID =~ /^(org[.|-]polarresearch\-)/
        comment += "Source: http://risapi.data.npolar.no/oai?verb=GetRecord&metadataPrefix=dif&identifier=oai:ris.npolar.no:#{dif.Entry_ID} \n"
      end
      comment += "Transformed from DIF XML by #{self.class.name} at #{DateTime.now.xmlschema}"
      comment
    end

    def href(id, format="json")
      "#{base.gsub(/\/$/, "")}/#{id}.#{format}"
    end

    def licences
        []
    end

    # id = SHA1-UUID of http://api.npolar.no/dataset/{Entry_ID}
    # (or SHA1-UUID of DOI)
    def id
      if doi?
        uuid(doi)
      else
        uuid(self.class.uri(dif.Entry_ID))
      end
    end

    def self.uri(id)
      "http://api.npolar.no/dataset/#{id}"
    end

    def iso_topics
      if dif.ISO_Topic_Category? and dif.ISO_Topic_Category.respond_to?(:map)
        dif.ISO_Topic_Category.map {|i| normalize_iso_topics(i) }
      end
    end
    
    def tags
      tags = []
      if dif.Keyword?
        tags += dif.Keyword
      end
      if dif.Project?
        tags += dif.Project.map {|p| p.Short_Name }
      end
      tags.uniq
    end

    def topics
      guess_topics
    end
    
    def quality
      dif.Quality
    end
    
    def published
      date = dif.DIF_Creation_Date ||= Date.new(-1).xmlschema
      date += "T12:00:00Z" unless date == "" or date =~ ISO8601_DATETIME_REGEX
      date
    end

    def schema
      ::Metadata::Dataset::JSON_SCHEMA_URI
    end
    
    def collection
      "dataset"
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

    def draft
      draft = "no"
      if dif.Private == "True"
        draft = "yes"
      end
      draft
    end
    
    def summary
      summary = ""

      if dif.Summary?
        if dif.Summary.is_a?(Hashie::Mash) and dif.Summary.Abstract?
          summary += dif.Summary.Abstract
        else
          summary += dif.Summary
        end
      end
      summary
    end
    
    def investigators
      people.select {|c| c.roles.include? "principalInvestigator" }
    end
    
    def edits
      []
    end
    
    # people <= Personnel
    def people
      people = []

      if dif.Personnel? # It's not always there (for invalid documents)
        people += dif.Personnel.map { |p|
        self.class.person_from_personnel(p)
      }
      end
      if dif.Data_Center?
        dif.Data_Center.each do |dc|
          if dc.Personnel?
            people += dc.Personnel.map { |p|
              self.class.person_from_personnel(p)
          }
          end
        end
      end

      people  
    end

    # organisations <= Data_Center
    # DIF Data_Center => organisation with "owner" role.
    # If the Data_Center is the Norwegian Polar Institute, default roles are used
    def organisations

      orgs = []

      if dif.Data_Center? and dif.Data_Center.any?
        dif.Data_Center.select {|dc| dc.Data_Center_Name? }.each {|dc|          

          roles = ["owner"]
          name = dc.Data_Center_Name.Long_Name
          url = dc.Data_Center_URL.gsub(/^http:\/\/www\./, "http://").gsub(/\/$/, "")
          links = [{ "rel" => "owner", "href" => url, "title" => dc.Data_Center_Name.Long_Name }]

          if  dc.Data_Center_Name.Long_Name =~ /Norwegian Polar Institute/
            name = "Norwegian Polar Institute"
            roles += ["originator", "publisher", "pointOfContact", "resourceProvider"]
            links << { "rel" => "publisher", "href" => "http://data.npolar.no", "title" => "Norwegian Polar Institute" }
          end
          
          id = URI.parse(url).host

          orgs << Hashie::Mash.new({
            "id" => id,
            "name" => name,
            "gcmd_short_name" => dc.Data_Center_Name.Short_Name,
            "roles" => roles,
            "links" => links
          })      
        }
      end
      
      if orgs.none?
        if self.dif.to_json =~ /(NPI|Norwegian Polar Institute)/
          orgs << Hashie::Mash.new(Metadata::Dataset.npolar)
        elsif not dif.Originating_Metadata_Node?
          orgs << Hashie::Mash.new(Metadata::Dataset.npolar("publisher"))
        end
      end

      orgs
    end
    
    # Placenames <= Location    
    def placenames
      
      (dif.Location||[]).select {|location| location.Detailed_Location?}.map {
        |location|
          Hashie::Mash.new({
            "placename" => location.Detailed_Location,
            "area" => area_from_location(location),
            "country" => guess_country_code_from_location(location),
        })
      }
    end 


    # coverage <= Spatial_Coverage
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
    #  2. Parent_DIF
    #  3. Data_Set_Citation (DOI + online resource)
    #
    def links
      links = []

      # 1. Related_URL
      if dif.Related_URL?
      
      dif.Related_URL.each do | link |

        if link.URL_Content_Type? and link.URL_Content_Type.Type?
          dif_type = link.URL_Content_Type.Type
        else
          dif_type = ""
        end
 
        rel = case dif_type
          when "GET DATA" then "data"
          when "VIEW PROJECT HOME PAGE" then "project"
          when "VIEW EXTENDED METADATA" then "metadata"
          when "GET SERVICE" then "service"
          when "VIEW RELATED INFORMATION" then "related"
          else dif_type
        end
         
        link.URL.each do | url |

          links << {
            "rel" => rel,
            "href" => url,
            "title" => link.Description,
            "type" => "text/html",
          }  
        end  
      end
      end

      # 2. Link to parent metadata
      unless object.Parent_DIF.nil? 
        dif.Parent_DIF.each do | parent |
          
            links << {
              "rel" => "parent",
              "href" => base+uuid(self.class.uri(parent))+".json",
              "type" => "application/json"
            }
           
        end
      end
      
      # 3. Links to DOI and "Online Resource" (metadata)
      # @todo

      #if id =~ /^http\:\/\//
      #  uri = id  
      #else
      #  uri = href(id, "json")
      #end

      # Move to model



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
      dif.Use_Constraints
    end

    def restricted
      restrictions.nil?
    end

    def restrictions
      return dif.Access_Constraints
    end
    
    def sets
      sets = []
      
      (dif.IDN_Node||[]).each do | node |
        
        case( node["Short_Name"] )
          when "IPY" then sets += ["IPY", "GCMD"]
          when "DOKIPY" then sets << "DOKIPY"
          when /^ARCTIC\/?.*/ then sets << "arctic"
          when /^AMD\/?.*/ then sets << "antarctic"
        end
        
      end
      if (topics||[]).include? "oceanography" or (topics||[]).include? "seaice" or (iso_topics||[]).include? "oceans"
        sets << "NMDC"
      end

      sets.uniq
    end
    
    def gcmd      
      { "sciencekeywords" => dif.Parameters||[],
        "instruments" => dif.Sensor_Name||[],
        "locations" => dif.Location||[],
        "projects" => dif.Project||[],
        "resolutions" => dif.Data_Resolution||[], # unbounded
        "disciplines" => dif.Discipline||[],
        "idn_nodes" => dif.IDN_Node||[],
        "paleo_temporal_coverage" => dif.Paleo_Temporal_Coverage||[],
        "instruments" => dif.Sensor_Name||[],
        "platforms" => dif.Source_Name||[],
        "extended" => dif.Extended_Metadata||[],
        "citation" => dif.Entry_ID !~ /^org[.|-]polarresearch\-/ ? dif.Data_Set_Citation||[] : [], # Yes, it's unbounded
        "references" => dif.Reference||[],
        "entry_id" => dif.Entry_ID
      }
    end
       
    def parameters
      return [] if object.Parameters.nil?
      object.Parameters
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

  
    def doi?
      dif.Data_Set_Citation? and dif.Data_Set_Citation.any? and dif.Data_Set_Citation[0].Dataset_DOI?
    end

    def doi
      dif.Data_Set_Citation[0].Dataset_DOI
    end


    def title
      dif.Entry_Title
    end

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
        topics = tags.map {|c| guess_topic_from_tags(c)}
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
        ["biology", "marine"]
      elsif parameter.Term =~ /VEGETATION/i
        ["biology", "vegetation"]
      elsif parameter.Term =~ /ECOLOGICAL DYNAMICS|ECOSYSTEMS/i
        ["biology", "ecology"]
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
        "atmosphere"
      end
    end

    def guess_topic_from_tags(tag)
      if tag =~ /(Persistent organic pollutants|POPs)/
        "ecotoxicology"
      end
    end

    def guess_topic_from_title(title)
      if title =~ /geology|geological/i
        "geology"
      elsif title =~ /bird|reindeer|fauna|ecology|faeces|fox|seal|walrus|vegetation|population dynamics|lichen/i
        "biology"
      elsif title =~ /radiation|spectral|meteorological|aerosol|ozone/i
        "atmosphere"
      elsif title =~ /sea ice|fast ice|iceberg|ice/i
        "seaice"
      elsif title =~ /snow/i
        "glaciology"
      elsif title =~ /map|maps/
        "maps"
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

  end
  
end
