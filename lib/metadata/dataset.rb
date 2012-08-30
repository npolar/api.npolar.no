require "hashie"

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
    
    def to_solr
    end
    
    def to_dif
    end
    
  end
  
end