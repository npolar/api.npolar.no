# encoding: utf-8
module Views
  module Ecotox
    class Index < Npolar::Mustache::JsonView

      def initialize
        @hash = { :_id => "ecotox_index",
          :title => "Ecotox: Environmental pollutants"
        }
      end

      def collections
        ["report"].sort.map {|c| {:title => c, :href => "/ecotox/#{c}"}}
      end

    end
  end
end