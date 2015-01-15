module Npolar
  module Api

    # Utility class to inject a service beheind the scenes
    class Bootstrap

      attr_accessor :log, :service
      attr_writer :uri

      # Bootstrap service by creating database and search index
      # @param service [Service] http://api.npolar.no/schema/api
      #  service.storage: Storage adapter ("CouchDB")
      #  service.database": Service database ("api")
      def bootstrap(service, inject_service_document=true)

        unless service.is_a? Service
          service = Service.factory(service)
        end
        unless service.valid?
          raise ArgumentError, "Service seed for #{service.path} is invalid: #{service.errors}"
        end

        # Create service database
        if service.database?
          create_database(service)
        end

        # PUT service document (inject into the api service database)
        # [A service like /user points to it's own database, but not to the fact
        # that the user service configuration needs to go in the "api" database
        #(defined in "service-api.json")
        api = Service.factory("service-api.json")

        client = Npolar::Api::Client::JsonApiClient.new(uri+"/"+api.database+"/"+service.id)
        client.log = log
        client.username = URI.parse(uri).user
        client.password = URI.parse(uri).password

        # If this was run on create from Service.after_lambda [on POST/PUT] => we don't want to reinject the service document
        if true == inject_service_document
          response = client.put(service.to_json)
          if response.status == 201
            log.info "Stored service configuration '#{service.id}' in #{service.storage} database  #{api.database}: #{response.body} "
          else
            log.warn "Failed storing service configuration \"#{service.id}\", status #{response.status}: #{response.body}"
          end
        end

        if service.search?
          create_search(service)
        end

      end

      def create_database(service)

        unless service.database? and service.storage?
          return
        end

        client = Npolar::Api::Client::JsonApiClient.new(uri+"/"+service.database)

        client.log = log
        log.fatal client.uri.to_s
        response = client.head

        if 404 == response.status
          log.info "Creating #{service.storage} \"#{service.database}\" database"

          #unless uri =~ /^http(s)?:\/\/(\w+):(\w+)@(\w+)(:\d+)?/
          #  raise ArgumentError, "Cannot create database for #{service.path}, please set uri like https://username:password@localhost:6984"
          #end

          client.username = URI.parse(uri).user
          client.password = URI.parse(uri).password

          response = client.put("")

          if 201 == response.status
            log.info "Database \"#{service.database}\" created: #{response.body}"
          else
            log.error "Failed creating database \"#{service.database}\" status #{response.status}: #{response.body}"
            raise "Failed creating database for #{service.path} API"
          end
        elsif 200 == response.status
          log.debug "#{service.storage} database for #{service.path} exists: #{service.database}"
        else
          log.warn "Error on HEAD #{service.storage} database for #{service.path}, response status: #{response.status}"
        end
      end

      def create_search(service)
        if service.search.engine =~ /Elasticsearch/i
          create_elasticsearch(service)
        end
      end

      # Create Elasticsearch index, mapping, and river
      # Elastic needs a little napping, so there is 3 sleeps
      def create_elasticsearch(service)

        if service.storage =~ /Couch/
          delete_elasticsearch_couchdb_river(service)
          sleep(3)
        end

        delete_elasticsearch_index(service)

        sleep(3)

        create_elasticsearch_index(service)

        create_elasticsearch_mapping(service)

        if service.storage =~ /Couch/
          create_elasticsearch_couchdb_river(service)
          sleep(3)
        end
      end

      # http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/indices-create-index.html
      def create_elasticsearch_index(service)

        elastic = service.search

        client = Npolar::Api::Client::JsonApiClient.new(elastic_uri(elastic).to_s)

        index_document_file = File.absolute_path(File.join(__dir__, "..", "..", "..", "search", "elasticsearch", "index.json"))

        if elastic.key?("index_document")
          index_document = elastic["index_document"]
        elsif File.exists? index_document_file
          index_document = JSON.parse(File.read(index_document_file))
        else
          index_document = {}
        end

        response = client.put(index_document.to_json)
        log.info "Index document #{index_document.to_json}"
        log.info "Elasticsearch index PUT #{client.uri}: #{response.status}"
      end

      def delete_elasticsearch_index(service)
        client = Npolar::Api::Client::JsonApiClient.new(elastic_uri(service.search).to_s)
        client.delete
      end

      # http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/indices-put-mapping.html#indices-put-mapping
      def create_elasticsearch_mapping(service)
        elastic = service.search
        mappingfile = File.absolute_path(File.join(File.dirname(__FILE__), "..", "..", "..", "search", "elasticsearch", "mapping", elastic["index"], "#{elastic.type}.json"))
        if File.exists? mappingfile

          mapping = File.read(mappingfile)
          uri = elastic_uri(elastic)

          uri.path += "/_mapping/#{elastic.type}"

          client = Npolar::Api::Client::JsonApiClient.new(uri.to_s)
          client.param = { ignore_conflicts: true }
          client.put(mapping)
        end
      end

      def create_elasticsearch_couchdb_river(service)

        elastic = service.search

        couchdb_uri = ENV["NPOLAR_API_COUCHDB"]
        couchdb_uri = URI.parse(couchdb_uri)

        river = { type: "couchdb",
          couchdb: { host: couchdb_uri.host, port: couchdb_uri.port, db: service.database, filter: nil,
          ignore_attachments: true },
          index: { index: elastic["index"], type: elastic["type"], bulk_size: "100", bulk_timeout: "50ms" }
        }.merge(elastic.river||{})

        # PUT new river
        uri = elastic_uri(elastic)
        uri.path = "/_river/#{elastic["index"]}_#{elastic["type"]}_river/_meta"
        client = Npolar::Api::Client::JsonApiClient.new(uri.to_s)
        client.put(river.to_json)
      end

      def delete_elasticsearch_couchdb_river(service)
        elastic = service.search
        uri = elastic_uri(elastic)
        uri.path = "/_river/#{elastic["index"]}_#{elastic["type"]}_river"
        client = Npolar::Api::Client::JsonApiClient.new(uri.to_s)
        client.delete
      end

      # Get all services
      def services(select=nil)
        Service.services
      end

      def apis
        services.select { |api| "http://api.npolar.no/schema/api" == api.schema }
      end

      def service
        Service.factory("service-api.json")
      end

      def uri
        @uri ||= ENV["NPOLAR_API_COUCHDB"].gsub(/\/$/, "")
      end

      def elastic_uri(elastic)
        elastic_uri = case elastic.url
        when /^http/
          elastic.url
        else
          ENV["NPOLAR_API_ELASTICSEARCH"]
        end
        elastic_uri = URI.parse(elastic_uri)

        elastic_uri.path = "/#{elastic["index"]}"

        elastic_uri
      end

    end

  end
end
