# encoding: utf-8
module Views
  module Map
    class Index < Npolar::Mustache::JsonView

      def initialize(attr = nil)
        @hash = attr ||= { "_id" => "seaice_index",
          :title => "Maps",
          :data => { "workspace" => "map", "collections" => collections} 
        }
      end

      def collections
        [] #::Seaice.collections.sort.map {|c| {:title => c, :href => "/#{::Seaice.workspace}/#{c}"}}
      end

    end
  end
end