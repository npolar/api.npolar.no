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
  
  class Dataset < Hashie::Mash
    
    attr_accessor :schema
    
    DIF_SCHEMA_URI = "http://gcmd.nasa.gov/Aboutus/xml/dif/dif.xsd"

    SCHEMA_URI = { "dif" =>  DIF_SCHEMA_URI,
      "json" => "http://api.npolar.no/schema/metadata/dataset",
      "xml" => DIF_SCHEMA_URI
    }

    class << self
      attr_accessor :formats, :accepts
    end

    def self.country_codes
      #  http://en.wikipedia.org/wiki/Arctic_Council + AQ
      ["CA", "DK", "GL", "FI", "FO", "IS", "NO", "RU", "SW", "AQ", "US"].sort
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

    def self.example_id
      "fe18cf19-8220-5df8-a22b-34089bfef97e"
    end

    def self.licenses
      ["http://data.norge.no/nlod/no/1.0", "http://creativecommons.org/licenses/by/3.0/no/"]
    end
    
    def self.list_formats
      [{:format => "json", :title => "List ids (JSON Array)"}]
    end

    def self.uri
      "/metadata/dataset"
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
      "Datasets from the Norwegian Polar Institute"
    end
    
    def to_solr
    end
    
    def from_dif
    end
    
    def to_dif
    end
    
    def valid?
      JSON::Validator.validate( schema, self )
    end
    
    def validate
      JSON::Validator.fully_validate( schema, self )
    end
    
  end
  
end