# encoding: utf-8
module Views
  module Ocean
    class Index < Npolar::Mustache::JsonView

      def initialize
        @hash = { :_id => "ocean_index",
          :title => "Oceanography data"
        }
      end

      def collections
        (1980 .. DateTime.now.year).to_a.reverse.map {|c| {:title => c.to_s, :href => "/ecotox/#{c}"}}
      end

    end
  end
end