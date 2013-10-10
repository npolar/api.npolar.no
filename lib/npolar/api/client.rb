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
          "Accept-Encoding" => "gzip,deflate",
          "Connection" => "keep-alive"
        },
        "timeout" => 600,           # open/read timeout in seconds
        "open_timeout" => 60      # connection open timeout in seconds
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
        all = get_body("_all", {:fields=>"*"})
        if model?
          all.map {|d| model.class.new(d)}
        end
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
        # FIXME Hashie::Mash will always respond to #valid? 
        if not model? or not model.respond_to?(:valid?)
          return true
        end

        validator = model.class.new(document_or_id)
        valid = validator.valid?
        
        if validator.errors.nil?
          return true
        end

        @errors = validator.errors # store to avoid revalidating
        valid = case valid
          when true, nil
            true
          when false
            false
        end
        valid
      end

    def username
      # export NPOLAR_HTTP_USERNAME=http_username
      @username ||= ENV["NPOLAR_API_USERNAME"]
    end

    def password
      # export NPOLAR_HTTP_PASSWORD=http_password
      @password ||= ENV["NPOLAR_API_PASSWORD"]
    end

    end
  end
end