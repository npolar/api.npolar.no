require "faraday"

module Npolar
  class Http

    attr_accessor :log
    attr_reader :response
    attr_writer :username, :password

    extend Forwardable # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/forwardable/rdoc/Forwardable.html

    # Delegate HTTP verbs to Faraday
    def_delegators :http, :delete, :get, :head, :patch, :post, :put

    def initialize(base="http://api.npolar.no", options={}, &builder)
      @base = base
      @options = options
      @http = http(&builder)
      @log = ENV["NPOLAR_ENV"] == "test" ? ::Logger.new("/dev/null") : ::Logger.new(STDERR)
    end

    # Base URI like "http://api.npolar.no"
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
        #f.response :logger # Log to STDOUT

        f.build do |b|
          builder.call(b)
        end if builder

        f
      end
    end

    def get_body(uri, params={})
      response = get(uri, params)
      unless (200..399).include? response.status
        raise Exception, "GET #{uri} failed with status: #{response.status}"
      end
      response.body
    end

    def host
      @http.host
    end

    def options
      @options
    end

    def auth?
      #
      username != "" and password != null
    end

    def username
      # export NPOLAR_HTTP_USERNAME=http_username
      @username ||= ENV["NPOLAR_HTTP_USERNAME"] ||= ""
    end

    def password
      # export NPOLAR_HTTP_PASSWORD=http_password
      @password ||= ENV["NPOLAR_HTTP_PASSWORD"] ||= ""
    end

  end
end
