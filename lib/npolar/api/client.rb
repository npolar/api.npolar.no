require "faraday"
require "faraday_middleware"

module Npolar
  module Api 
  
    class Client < Npolar::Http

      OPTIONS = { :headers =>
        { "User-Agent" => "#{self.name}",
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "Accept-Charset" => "UTF-8",
          "Accept-Encoding" => "gzip,deflate"
          #Connection',"keep-alive"},
        }
      }
      # Before post, grab schema (get current revision)

      attr_accessor :model

      def initialize(base="http://api.npolar.no", options=OPTIONS, &builder)
        @base = base
        @options = options
        @http = http(&builder)
        @log = ENV["NPOLAR_ENV"] == "test" ? ::Logger.new("/dev/null") : ::Logger.new(STDERR)
      end

      def all
        get_body("_all", {:fields=>"*"})
      end
      alias :feed :all

      def errors(document_or_id)
        @errors ||= model.merge(document_or_id).errors
      end

      def get_body(uri, params={})
        # edit URI and model => instantiate
        result = JSON.parse(super)
        if result.is_a? Hash
          Hashie::Mash.new(result)
        else
          result
        end
        
      end

      # All ids
      def ids
        get_body("_ids").ids
      end

      # All invalid documents
      def invalid
        valid(false)
      end

      def model?
        not @model.nil?
      end

      def uris
        ids.map {|id| base+"/"+id }
      end

      # All valid documents
      def valid(condition=true)
        all.select {|d| condition == valid?(d) }.map {|d| model.class.new(d)}
      end

      def valid?(document_or_id)
        unless model?
          raise "Cannot validate without model"
        end
        m = model.class.new(document_or_id)
        v = m.valid?
        @errors = m.errors # store to avoid revalidating
        v
      end

    end
  end
end