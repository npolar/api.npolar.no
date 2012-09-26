require "hashie"
require "json-schema"

module Metadata

  # The API's metadata object.
  #
  # [Functionality]
  #   * Contains all metadata details.
  #   * Exports to a Solr Hash (JSON)
  #   * Exports to DIF XML Hash
  #
  # [License]
  #   This code is licensed under the {http://www.gnu.org/licenses/gpl.html GNU General Public License Version 3} (GPLv3)
  #
  # @author Ruben Dens
  # @author Conrad Helgeland
  
  class Dataset < Hashie::Mash
    
    attr_accessor :schema

    def self.country_codes
    end

    def self.sets
      ["ARCTIC", "ANTARCTICA", "IPY:NO", "IPY", "Cryoclim", "NMDC"]
    end

    def self.oai_sets
      [ {:spec => "ARCTIC", :name => "Arctic"},
        {:spec => "ANTARCTICA", :name => "Antarctic"},
        {:spec => "IPY:NO", :name => "IPY (Norway)", :description => "Norwegian contributions to the International Polar Year"},
        {:spec => "IPY", :name => "IPY", :description => "Datasets from the International Polar Year (2007-2008)"},
        {:spec => "Cryoclim", :name => "Cryoclim", :description => "Cold datasets"},
        {:spec => "NMDC", :name => "Norwegian Marine Data Centre", :description => "Marine datasets"}
      ]
    end

    def self.summary
      "Discovery-level metadata, in particular DIFs targeted at NASA's Global Change Master Directory."
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