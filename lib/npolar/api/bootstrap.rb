module Npolar
  module Api

    # Bootstrap API service and user databases (atm. REST/CouchDB only)
    # Bootstrap is primarily intended for creating /service and /user databases used to autorun APIs and authenticating and authorizing users
    class Bootstrap

      attr_accessor :log, :service
      attr_writer :uri

      # @param service [Service] http://api.npolar.no/schema/api
      #  service.storage: Storage adapter ("CouchDB")
      #  service.database": Service database ("api")
      def bootstrap(service, force=true)

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

        # PUT service document (in the api database)
        # (A service like /user points to it's own database, but not to the fact
        # that the user service configuration needs to go in the "api" database
        #(defined in "service-api.json")
        api = Service.factory("service-api.json")

        client = Npolar::Api::Client::JsonApiClient.new(uri+"/"+api.database+"/"+service.id)
        client.log = log
        client.username = URI.parse(uri).user
        client.password = URI.parse(uri).password

        response = client.head
        if force == true or 404 == response.status
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
        #log.debug client.uri
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
        create_elasticsearch(service)
      end
      
      # Create Elasticsearch index, mapping, and river
      def create_elasticsearch(service)
        create_elasticsearch_index(service)
        create_elasticsearch_mapping(service)
        if service.storage =~ /Couch/
          create_elasticsearch_couchdb_river(service)
        end
      end
      
      def create_elasticsearch_index(service)
        elastic = service.search
        
        elastic_uri = case elastic.url
        when /^http/
          elastic.url
        else
          ENV["NPOLAR_API_ELASTICSEARCH"]
        end
        elastic_uri = URI.parse(elastic_uri)
        
        elastic_uri.path = "/#{elastic["index"]}"
        
        client = Npolar::Api::Client::JsonApiClient.new(elastic_uri.to_s)

        client.delete
        response = client.put('{"index" : {
  "analysis" : {
      "analyzer" : {
          "default" : {
              "tokenizer" : "standard",
              "filter" : ["standard", "lowercase", "preserve_ascii"]
          }
      },
      "filter" : {
          "preserve_ascii" : {
              "type" : "asciifolding",
              "preserve_original" : true
          }
      }
    }
  }
}')
      
      log.info "Elasticsearch index PUT #{elastic_uri}: #{response.status}"
      end
      
      
      def create_elasticsearch_mapping(service)
        # £todo
        #curl -XPUT http://elastic.example.com:9200/polarbear/_mapping/interaction -d@search/elasticsearch/mapping/polarbear/interaction.json
      end
      
      def create_elasticsearch_couchdb_river(service)
        
        elastic = service.search
        
        elastic_uri = case elastic.url
        when /^http/
          elastic.url
        else
          ENV["NPOLAR_API_ELASTICSEARCH"]
        end
        elastic_uri = URI.parse(elastic_uri)
        
        couchdb_uri = ENV["NPOLAR_API_COUCHDB"]
        couchdb_uri = URI.parse(couchdb_uri)

        river = { type: "couchdb",
          couchdb: { host: couchdb_uri.host, port: couchdb_uri.port, db: service.database, filter: nil },
          index: { index: elastic["index"], type: elastic["type"], bulk_size: "100", bulk_timeout: "50ms" }
        }.merge(service.river||{})
        
        elastic_uri.path = "/_river/#{elastic["index"]}_#{elastic["type"]}_river"
        
        client = Npolar::Api::Client::JsonApiClient.new(elastic_uri.to_s)
        client.delete
        
        elastic_uri.path += "/_meta"
        client = Npolar::Api::Client::JsonApiClient.new(elastic_uri.to_s)

        client.put(river.to_json)
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

    end

    # user hash ldif

  end
end
