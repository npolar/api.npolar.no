# encoding: utf-8

module Views
  module Metadata
    class Index < Npolar::Mustache::JsonView

      def initialize  
        @hash = {
          :_id => "view_metadata_index",
          :workspace => "metadata",
          :collections => [{ :collection => "dataset", :href=>"/metadata/dataset", :title =>"Dataset metadata" }],
          :licenses => [""],
          :h1_title => "<a title=\"api.npolar.no\" href=\"/\">api</a>.npolar.no/metadata",
          :summary => "Discovery-level metadata. RESTful. Methods: GET, HEAD, POST PUT, DELETE. Harvestable using OAI-PMH. Accepts DIF XML and JSON, outputs DIF XML, JSON and ISO 19000 series XML.",
          :oai => {:verbs => [
            {:verb => "GetRecord", :example => "&metadataPrefix=dif&identifier=org-polarresearch-689"},
            {:verb => "Identify"},
            {:verb => "ListIdentifiers"},
            {:verb => "ListMetadataFormats"},
            {:verb => "ListRecords"},
            {:verb => "ListSets"}],
            :summary => ""
          }
        }
      end

      

    end
  end
end