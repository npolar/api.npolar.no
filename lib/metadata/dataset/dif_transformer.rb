require "hashie"

module Metadata
  module Dataset
    
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
    
    class DifTransformer < Hashie::Mash
      
      def format
        return "dif" if self.Entry_ID
        return "dataset" if self.id
        nil
      end
      
    end
    
  end
end
