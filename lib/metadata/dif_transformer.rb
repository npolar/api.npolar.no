require "hashie"

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
    
    ISO_8601 = /^(\d{4})-(0[1-9]|1[0-2])-([12]\d|0[1-9]|3[01])T([01]\d|2[0-3]):([0-5]\d):([0-5]\d)Z$/
    
    DATASET_MAP = [
      :source, :id, :title, :summary, :progress, :investigators,
      :contributors, :rights, :activity, :locations, :tags,
      :quality, :science_keywords, :draft, :published, :updated, :editors
    ]
    
    DIF_MAP = [ :entry_id ]
    
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
    
    def source
      Hashie::Mash.new( { :dif => object } )
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
        
        periods << Hashie::Mash.new({"start_date" => start, "stop_date" => stop})
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
        # query placenames for area and nearest placename or central placename (bounding box)?
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
        # query placenames for area and nearest placename or central placename (bounding box)?
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
    
    def science_keywords
      object.Parameters
    end
    
    def draft
      "no"
    end
    
    #################################
    ###### To GCMD DIF Format #######
    #################################
    
    def to_dif
    
    end
    
  end
  
end