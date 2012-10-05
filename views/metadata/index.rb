# encoding: utf-8
module Views
  module Metadata
    class Index < Views::Workspace

      def initialize  
        @hash = {
          :_id => "metadata_index",
          :workspace => "metadata",
          :licenses => model.licenses,
          :summary => "Discovery-level metadata",
          :oai => {:verbs => [
            {:verb => "GetRecord", :example => "&metadataPrefix=dif&identifier=#{::Metadata::Dataset.example_id}"},
            {:verb => "Identify"},
            {:verb => "ListIdentifiers"},
            {:verb => "ListMetadataFormats"},
            {:verb => "ListRecords"},
            {:verb => "ListSets"}],
            :summary => "",
          },
          :data => { "workspace" => ::Metadata.workspace, "collections" => collections.map {|c|c[:href]} } 
        }
      end

      def collections
        collections = ::Metadata.collections.sort.map {|c|
          { :title => c.capitalize,
            :href => "/#{::Metadata.workspace}/#{c}",
            :list_formats => static(c, :list_formats),
            :example_href => static(c, :uri)+"/"+static(c, :example_id),
            :summary => static(c, :summary),
            :formats => static(c, :formats).map {|f| { :format => f } },
            :accepts => static(c, :accepts).map {|a| { :accept => a, :schema_uri => static(c, :schema_uri, a) } }
          }
        }
      end
  
      protected

      def model
        ::Metadata::Dataset
      end

      def static(collection, method, *args)
        case collection
          when "dataset" then ::Metadata::Dataset.send(method, *args)
          when "oai" then []
          else []
        end
      end

    end
  end
end