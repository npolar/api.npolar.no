# encoding: utf-8
module Views
  module Seaice
    class Index < Npolar::Mustache::JsonView

      def initialize(attr = nil)
        @hash = attr ||= { "_id" => "seaice_index",
          :title => "Seaice and its physical properties",
          :data => { "workspace" => ::Seaice.workspace, "collections" => ::Seaice.collections} 
        }
      end

      def collections
        ::Seaice.collections.sort.map {|c| {:title => c, :href => "/#{::Seaice.workspace}/#{c}"}}
      end

    end
  end
end