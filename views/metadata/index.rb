# encoding: utf-8
module Views
  module Metadata
    class Index < Npolar::Mustache::JsonView

      def initialize  
        @hash = { :_id => "metadata_index",
          :title => "Metadata",
          :oai => {:verbs => [{:verb => "GetRecord", :example => "&identifier=x&metadataPrefix=dif"},
            {:verb => "Identify"},
            {:verb => "ListIdentifiers"},
            {:verb => "ListMetadataFormats"},
            {:verb => "ListRecords"},
            {:verb => "ListSets"}],
            :summary => ::Metadata::Dataset.summary,
          },

          :data => { "workspace" => ::Metadata.workspace, "collections" => collections.map {|c|c[:href]} } 
        }
      end

      def collections
        ::Metadata.collections.sort.map {|c|
          {:title => c.capitalize, :href => "/#{::Metadata.workspace}/#{c}", :list_formats => list_formats(c)}
        }
      end
  

      protected

      def list_formats(collection)
        list_formats = [{:format => "json", :title => "JSON"}]
        if "dataset" == collection
          #list_formats << {:format => "xml", :title => "XML (OAI-PMH/DIF)"}
        end
        list_formats
      end

    end
  end
end