# encoding: utf-8
module Views
  module Biology
    class Index < Views::Workspace

      self.template = Views::Workspace.template

      def initialize
        @hash = { :_id => "biology_index",
          :workspace => "biology",
        }
      end

      def collections
        ["observation", "marine"].sort.map {|c| {:title => c, :href => "/#{workspace}/#{c}"}}
      end

    end
  end
end
