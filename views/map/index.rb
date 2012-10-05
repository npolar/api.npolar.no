# encoding: utf-8
module Views
  module Map
    class Index < Views::Workspace
      def initialize(attr = nil)
        @hash = attr ||= { "_id" => "seaice_index",
          :title => "Maps",
          :data => { "workspace" => "map", "collections" => collections} 
        }
      end

      def collections
        ["archive"]
      end

    end
  end
end