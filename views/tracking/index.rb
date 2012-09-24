# encoding: utf-8
module Views
  module Tracking
    class Index < Npolar::Mustache::JsonView

      def initialize
        @hash = { :_id => "tracking_index",
          :title => "Tracking data"
        }
      end

      def collections
        ["argos", "iridium"].sort.map {|c| {:title => c, :href => "/tracking/#{c}"}}
      end

    end
  end
end