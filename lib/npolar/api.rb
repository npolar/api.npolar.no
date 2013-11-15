module Npolar
  module Api

    class << self
      attr_writer :log, :base
    end

    def self.base
      @base||="http://api.npolar.no"
    end
    
    def self.facets
     ["collection", "workspace", "accept_mimetypes", "accept_schemas", "formats", "relations", "topics", "sets", "category", "country",
      "draft", "editors", "hemisphere", "investigators", "licences", "link", "methods", "parameter", "person", "placename", "project",
      "source", "iso_topics", "tags"]
    end

    def self.log
      @@log ||= begin
        log = Logger.new(STDERR)
        log.level = case ENV["RACK_ENV"]
          when "development" then log.level = Logger::DEBUG
          when "test" then log.level = Logger::UNKNOWN
          when "production" then log.level = Logger::INFO
        end
        log
      end
    end
    
    def uuid(uri)
      UUIDTools::UUID.sha1_create( UUIDTools::UUID_DNS_NAMESPACE, uri )
    end

  end
end
