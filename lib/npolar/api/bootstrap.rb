module Npolar
  module Api

    # Bootstrap API service and user databases (atm. REST/CouchDB only)

    class Bootstrap

      attr_accessor :log, :service
      attr_writer :uri

      # @param service Service
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
