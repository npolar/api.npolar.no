module Npolar
  module Api

    # Bootstrap API databases (REST/CouchDB only)
    
    class Bootstrap

      attr_accessor :log, :service
      attr_writer :uri

      # @param service Service
      #  service.storage: Storage adapter ("CouchDB")
      #  service.database": Service database ("api")
      def bootstrap(service)
        unless service.is_a? Service
          service = Service.factory(service)
        end
        unless service.valid?
          raise ArgumentError, "Service seed for #{service.path} is invalid: #{service.errors}"
        end
        
        unless uri =~ /http(s)?:\/\/(\w+):(\w+)@(\w+)(:\d+)?/
          raise ArgumentError, "Cannot bootstrap #{service.path}, please set uri like https://username:password@localhost:6984"
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
        
        client = Npolar::Api::Client.new(uri+"/"+api.database+"/"+service.id)
        response = client.head
        if 404 == response.status 
          response = client.put("", service.to_json)
          if response.status == 201
            log.info "Stored service configuration '#{service.id}' in #{service.storage} database  #{api.database}: #{response.body} "
          else
            log.warn "Failed storing service configuration \"#{service.id}\", status #{response.status}: #{response.body}"
          end
        end

      end

      def create_database(service)

        client = Npolar::Api::Client.new(uri+"/"+service.database)
        response = client.head 
        if 404 == response.status
          log.info "Creating #{service.storage} \"#{service.database}\" database"

          unless uri =~ /http(s)?:\/\/(\w+):(\w+)@(\w+)(:\d+)?/
            raise ArgumentError, "Cannot create database for #{service.path}, please set uri like https://username:password@localhost:6984"
          end

          client.username = $1
          client.password = $2
        
          response = client.put
          if 201 == response.status
            log.info "Database \"#{service.database}\" created: #{response.body}"
          else
            log.error "Failed creating database \"#{service.database}\" status #{response.status}: #{response.body}"
            raise "Failed creating database for #{service.path} API"
          end
        else
          log.debug "#{service.storage} database for #{service.path} exists: #{service.database}"
        end
      end

      # Get all services
      def services(select=nil)
        client = Npolar::Api::Client.new(Npolar::Storage::Couch.uri+"/#{service.database}")
        
        client.get_body("_all_docs", {"include_docs"=>true}).rows.map {|row|
          Service.new(row.doc)
        }
      end

      def apis
        services.select { |api| "http://data.npolar.no/schema/api" == api.schema }
      end

      def service
        Service.factory("service-api.json")
      end


      def uri
        @uri ||= ENV["NPOLAR_API_COUCHDB"].gsub(/\/$/, "")
      end

    end
  end
end
