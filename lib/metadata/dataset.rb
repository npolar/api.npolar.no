require "hashie"
require "json-schema"

module Metadata

  # Dataset metadata model
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

    def self.country_codes
      #  http://en.wikipedia.org/wiki/Arctic_Council + AQ
      ["CA", "DK", "GR", "FI", "FO", "IS", "NO", "RU", "SW", "AQ", "US"].sort
    end

    def self.sets
      ["ARCTIC", "ANTARCTICA", "IPY:NO", "IPY", "Cryoclim", "NMDC"]
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
    def self.oai_sets
      [ {:spec => "artic", :name => "Arctic datasets"},
        {:spec => "antarctic", :name => "Antarctic datasets"},
        {:spec => "IPY:NO", :name => "IPY (Norway)", :description => "Norwegian contributions to the International Polar Year"},
        {:spec => "IPY", :name => "IPY", :description => "Datasets from the International Polar Year (2007-2008)"},
        {:spec => "cryoclim", :name => "Cryoclim", :description => "Cold datasets"},
        {:spec => "nmdc", :name => "Norwegian Marine Data Centre", :description => "Marine datasets"},
        {:spec => "gcmd", :name => "Global Change Master Directory" }
      ]
    end

    def self.summary
      "Discovery-level metadata, in particular DIFs targeted at NASA's Global Change Master Directory."
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