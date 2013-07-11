require "hashie/mash"

module Npolar
  module Api
    class CoreModel < Hashie::Mash

#collection
#workspace
#accept_mimetypes
#accept_schemas
#formats
#relations
#sets
#category
#country
#day
#draft
#investigators
#licences
#year
#month
#placename
#iso_topics
#climatology/meteorology/atmosphere (2) elevation (2) environment (2) geoscientific information (2) boundaries (1) economy (1)
#updated
#edit (link-edut edit-uri uri)

      def self.core_metadata_symbols
        [:workspace, :collection, :id, :topic, :set, :category, :links, :title, :latitude, :longitude, :year, :month, :day, :accept_mimetype, :relation, :parameter, :unit, :species, :draft, :state ]
      end

      def self.factory(hash={})
        m = self.new
        core_metadata_symbols.each do |k| 
          m[k]= hash.has_key?(k) ? hash[k] : nil
        end
        m
      end

    end
  end       
end