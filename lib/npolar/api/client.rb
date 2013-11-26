require "faraday"
require "faraday_middleware"

module Npolar
  module Api 
    class Client
    attr_accessor :model, :log
    attr_reader :response, :options
    attr_writer :username, :password

    extend Forwardable # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/forwardable/rdoc/Forwardable.html
    
    # Delegate HTTP verbs to Faraday
    def_delegators :http, :delete, :get, :head, :patch, :post, :put, :basic_auth

      OPTIONS = { :headers =>
        { "User-Agent" => "#{self.name}",
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "Accept-Charset" => "UTF-8",
          "Accept-Encoding" => "gzip,deflate",
          "Connection" => "keep-alive"
        }
      }
      # Before post, grab schema (get current revision)

      def initialize(base="http://api.npolar.no", options=OPTIONS, &builder)
        @base = base
        @options = options
        @http = http(&builder)
        @log = ENV["NPOLAR_ENV"] == "test" ? ::Logger.new("/dev/null") : ::Logger.new(STDERR)
      end

      def all
        all = get_body("_all", {:fields=>"*"})
        if model?
          all = all.map {|d| model.class.new(d)}
        end
        all
      end
      alias :feed :all

      def base
        @base.gsub(/\/$/, "")
      end

      # The Faraday http object
      def http(&builder)
        @http ||= begin
          f = Faraday.new(base, options)
  
          if password != "" and username != ""
            #f.basic_auth username, password
          end
          f.response :logger # Log to STDOUT
          # "request.timeout" => 600           # open/read timeout in seconds
          # "open_timeout" => 60      # connection open timeout in seconds
  
          f.build do |b|
            builder.call(b)
          end if builder
  
          f
        end
      end

      def errors(document_or_id)
        @errors ||= model.merge(document_or_id).errors
      end

      def get_body(uri, params={})
        # edit URI and model => instantiate
        response = get(uri, params)
        unless (200..399).include? response.status
          raise Exception, "GET #{uri} failed with status: #{response.status}"
        end
        body = JSON.parse(response.body)
        if body.is_a? Hash
          Hashie::Mash.new(body)
        else
          body
        end
        
      end

      #def get_body(uri, params={})
      #    response = get(uri, params)
      #    unless (200..399).include? response.status
      #      raise Exception, "GET #{uri} failed with status: #{response.status}"
      #    end
      #    response.body
      #  end

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

        # Return true if validator is a Hash with errors key !
        # FIXME Hashie::Mash will always respond to #valid? 
        if validator.key? :valid? or validator.key? :errors
          return true
        end
        
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