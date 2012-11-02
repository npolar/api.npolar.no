# encoding: utf-8
module Views
  module Metadata
    class Index < Views::Workspace

      def initialize  
        @hash = {
          :_id => "view_metadata_index",
          :workspace => "metadata",
          :collections => [{ :collection => "dataset", :href=>"/metadata/dataset", :title =>"Dataset metadata" }],
          :licenses => [""],
          :summary => "Discovery-level metadata",
          :oai => {:verbs => [
            {:verb => "GetRecord", :example => "&metadataPrefix=dif&identifier=#{::Metadata::Dataset.example_id}"},
            {:verb => "Identify"},
            {:verb => "ListIdentifiers"},
            {:verb => "ListMetadataFormats"},
            {:verb => "ListRecords"},
            {:verb => "ListSets"}],
            :summary => "Discovery-level metadata",
          }
        }
      end

      

    end
  end
end