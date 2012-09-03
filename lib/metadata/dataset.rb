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