# encoding: utf-8
module Views
  module Metadata
    class Index < Npolar::Mustache::JsonView

      def initialize  
        @hash = { :_id => "metadata_index",
          :title => "Metadata",
          :data => { "workspace" => ::Metadata.workspace, "collections" => collections.map {|c|c[:href]} } 
        }
      end

      def collections
        ::Metadata.collections.sort.map {|c| {:title => c, :href => "/#{::Metadata.workspace}/#{c}"}}
      end

    end
  end
end