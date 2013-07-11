module Npolar
  module Api

    # Bootstrap API databases (REST/CouchDB only atm.)
    
    class Bootstrap

      attr_accessor :log, :uri

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
        
        uri = @uri ||= ENV["NPOLAR_API_COUCHDB"].gsub(/\/$/, "")
        unless uri =~  /http(s)?:\/\/(\w+):(\w+)@(\w+)(:\d+)?$/
          raise ArgumentError, "Cannot bootstrap #{service.path}, please set uri like https://username:password@localhost:6984"
        end
        
        # Create service database (the api client is just another rest client)
        client = Npolar::Api::Client.new(uri +"/"+ service.database)
        response = client.head 
        if 404 == response.status
          log.info "Bootstrapping #{service.storage} \"#{service.database}\" database"
          client.username = $1
          client.password = $2
        
          response = client.put
          if 201 == response.status
            log.info "Database \"#{service.database}\" created: #{response.body}"
          else
            log.error "Failed creating database \"#{service.database}\" status #{rsponse.status}: #{response.body}"
            raise "Failed starting API"
          end
        else
          log.debug "#{service.storage} database for #{service.path} exists: #{service.database}"
        end

        # PUT service document (in the api database)
        # A service like /user points to it's own database but not to the fact that the user service configuration needs to go in the "api" database (defined in "service-api.json")
        api = Service.factory("service-api.json")
        
        client = Npolar::Api::Client.new(uri +"/"+ api.database+"/"+service.id)
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
    end
  end
end
