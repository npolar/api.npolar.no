#encoding: utf-8

require "hashie"
require "uuidtools"

module Metadata
  # Dataset Transformer for DIF Documents.
  #
  # [Functionality]
  #   * Convert DIF documents into a metadata dataset.
  #   * Exports a metadata dataset to DIF.
  #
  # [License]
  #   This code is licensed under the {http://www.gnu.org/licenses/gpl.html GNU General Public License Version 3} (GPLv3)
  #
  # @author Ruben Dens
  # @author Conrad Helgeland
  
  class DifTransformer
    include Npolar::Api
    
    ISO_8601 = /^(\d{4})-(0[1-9]|1[0-2])-([12]\d|0[1-9]|3[01])T([01]\d|2[0-3]):([0-5]\d):([0-5]\d)Z$/

    DATASET_MAP = [
      :source, :_id, :id, :title, :summary, :progress, :investigators,
      :contributors, :rights, :activity, :locations, :links, :tags, :iso_topics,
      :quality, :science_keywords, :draft, :published, :updated, :editors, :sets
    ]
    
    DIF_MAP = {
      :entry_id => "Entry_ID",
      :entry_title => "Entry_Title",
      :summary_abstract => "Summary",
      :personnel => "Personnel",
      :spatial_coverage => "Spatial_Coverage",
      :dif_location => "Location",
      :temporal_coverage => "Temporal_Coverage",
      :iso_topic_category => "ISO_Topic_Category",
      :keyword => "Keyword",
      :related_url => "Related_URL",
      :reference => "Reference",
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
    
    attr_accessor :object
    
    def initialize( object = {} )
      if object.is_a? Hash
        self.object = Hashie::Mash.new( object )
      else
        raise ArgumentError, "Expecting a Hash object!"
      end
    end
    
    #################################
    ### To Native Metadata Format ###
    #################################
    
    def to_dataset
      dataset = Hashie::Mash.new
      
      # Loop equivalent of dataset.temporal_coverage = temporal_coverage
      DATASET_MAP.each do |method|
        dataset.send( method.to_s + '=', self.send( method ) )
      end
      
      dataset
    end
    
    def _id
      uuid(Metadata::Dataset.uri + "/" + object.Entry_ID)
    end
    
    def id
      object.Entry_ID
    end
    
    def title
      object.Entry_Title
    end
    
    def tags
      object.Keyword
    end
    
    def iso_topics
      if !object.ISO_Topic_Category.nil? && object.ISO_Topic_Category.any?
        categories = object.ISO_Topic_Category.map{ |c| c.downcase }
      end
    end
    
    def quality
      object.Quality
    end
    
    def rights
      text = ""
      #text += object.Use_Constraints unless object.Use_Constraints.nil?
      text += object.Access_Constraints unless object.Access_Constraints.nil?
      text
    end
    
    def published
      date = object.DIF_Creation_Date
      date += "T12:00:00Z" unless date == "" or date =~ ISO_8601
      date
    end
    
    def updated
      date = object.Last_DIF_Revision_Date
      date += "T12:00:00Z" unless date == "" or date =~ ISO_8601
      date
    end
    
    def progress
      unless object.Data_Set_Progress.nil?
        return object.Data_Set_Progress.downcase unless object.Data_Set_Progress == "In Work"
        "ongoing"
      end
    end
    
    def activity
      periods = []
      object.Temporal_Coverage.each do | period |
        
        start = ""
        start = period.Start_Date unless period.Start_Date.nil?
        start += "T12:00:00Z" unless start == "" or start =~ ISO_8601
        
        stop = ""
        stop = period.Stop_Date unless period.Stop_Date.nil?
        stop += "T12:00:00Z" unless stop == "" or stop =~ ISO_8601
        
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
              "email" => person.Email
            } )
          end unless person.Role.nil?
        end unless object.Personnel.nil?
      else
        raise ArgumentError, "unknown DIF role!"
      end
      
      contributors
    end
    
    def locations
      location_data = []
      
      object.Spatial_Coverage.each do | location |
        location_data << Hashie::Mash.new({
          "north" => location.Northernmost_Latitude.to_f,
          "east" => location.Easternmost_Longitude.to_f,
          "south" => location.Southernmost_Latitude.to_f,
          "west" => location.Westernmost_Longitude.to_f,
          "placename" => "",
          "area" => "",
          "country_code" => ""
        })
      end unless object.Spatial_Coverage.nil?
      
      object.Location.each do | location |
        
        #case( location.Location_Type )
        #when "ARCTIC" then area = "arctic"
        #when "ANTARCTICA" then area = "antarctic"
        #end unless location.Location_Type.nil?
        
        location_data << Hashie::Mash.new({
          "north" => nil,
          "east" => nil,
          "south" => nil,
          "west" => nil,
          "placename" => location.Detailed_Location,
          "area" => "",
          "country_code" => ""
        }) unless location.Detailed_Location.nil?
      end unless object.Location.nil?
      
      location_data
    end
    
    def links
      links = []
      
      object.Related_URL.each do | link |
        type = link["URL_Content_Type"]["Type"] unless link.nil? or link["URL_Content_Type"].nil?
        
        unless type.nil?
          
          case( type )
          when "GET DATA" then type = "dataset"
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
      
      object.Parent_DIF.each do | parent |
        links << {
          "rel" => "parent",
          "href" => uuid( Metadata::Dataset.uri + "/" + parent )
        } unless parent.nil?
      end unless object.Parent_DIF.nil?
      
      links
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
      object.Parameters
    end
    
    def draft
      "no"
    end
    
    def source
      Hashie::Mash.new( { :dif => object } )
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
        personnel << {
          "First_Name" => investigator.first_name.split(" ")[0],
          "Middle_Name" => investigator.first_name.split(" ")[1],
          "Last_Name" => investigator.last_name,
          "Email" => investigator.email,
          "Role" => ["Investigator"]
        }
      end unless object.investigators.nil?
      
      personnel
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
          when "arctic" then
            locations << {
              "Location_Category" => "GEOGRAPHIC REGION",
              "Location_Type" => "ARCTIC",
              "Detailed_Location" => detailed_location
            }
            locations << polar_region
          when /^(svalbard|jan_mayen)$/ then
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
          else
            locations << {
              "Location_Category" => "GEOGRAPHIC REGION",
              "Detailed_Location" => detailed_location
            } unless detailed_location.nil?
          end
          
        end
      end
      
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
      object.licenses.each_with_index do |license, i|
        constraints += license
        constraints += ", " unless (object.licenses.size - 1) == i
      end unless object.licenses.nil?
      
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
        
        unless type =~ /reference|doi/
        
          case( type )
          when "dataset" then type = "GET DATA"
          when "metadata" then type = "VIEW EXTENDED METADATA"
          when "project" then type = "VIEW PROJECT HOME PAGE"
          when "service" then type = "GET SERVICE"
          when "parent" then type = "GET RELATED METADATA RECORD (DIF)"
          else
            type = "VIEW RELATED INFORMATION" 
          end
          
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
      end
      
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
      object.published
    end
    
    def revision_date
      object.updated
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
    
  end
  
end
