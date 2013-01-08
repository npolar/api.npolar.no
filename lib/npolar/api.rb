module Npolar
  module Api

    class << self
      attr_writer   :log
    end
    
    def self.facets
     ["collection", "workspace", "accept_mimetypes", "accept_schemas", "formats", "relations", "group", "sets", "category", "country",
      "day", "draft", "editor",
      "hemisphere", "investigators", "iso_3166-1", "iso_3166-2", "licences", "link", "methods", "year", "month", "day", "org", "parameter", "person", "placename", "project", "protocols", "referenceYear",
      "source", "iso_topics", "tags", "updated"]
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
