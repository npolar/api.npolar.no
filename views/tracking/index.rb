# encoding: utf-8
module Views
  module Tracking
    class Index < Views::Workspace

      self.template = Views::Workspace.template

      def initialize
        @hash = { :_id => "tracking_index",
          :workspace => "tracking",
        }
      end

      def collections
        ["argos", "iridium"].sort.map {|c| {:title => c, :href => "/tracking/#{c}"}}
      end

    end
  end
end