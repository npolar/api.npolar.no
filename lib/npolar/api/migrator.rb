module Npolar
  module Api

    class Migrator
      attr_accessor :client, :migrations, :log, :batch, :uri
      attr_writer :select, :documents

      def documents
        @documents ||= client.invalid
      end

      def select
        @select ||= lambda {|d| true }
      end
      
      def run(really=false)
        log.info "#{self.class.name}#run against #{uri} --really=#{really}"      
        log.debug "Migrations: #{migrations}"

        # 1. Get all documents
        selected = documents.select(&select)
        log.info "#{selected.size} documents selected of #{client.ids.size} at #{uri}"
        
        fixed = []
        failed = []
        selected.each_with_index do |d,j|
          valid?(d)
          log.debug "Errors before: #{client.errors(d).to_json}\n#{d.to_json}"

          # 2. Get all migrations
          i = 0
          migrations.each do |condition, fixer|
            i += 1
            if condition.call(d)
      
              # 3. Apply fix directly to document (for the next fixer)
              d = fixer.call(d)
              log.debug "#{" "*2}Migration #{i}/#{migrations.size} for #{d.id}"
                      
            else
              log.debug "#{" "*2}Document #{d.id} not selected by condition #{condition}: [migration #{i}/#{migrations.size}]"
            end
          end

          # 4. Validate document
          if valid?(d)
            fixed << d
          else
            log.error "Failed migrating #{d.id}, errors: #{client.errors(d).to_json}\n#{d.to_json}"
            failed << d
          end
          log.debug "Finished document #{d.id} [##{j+1}/#{selected.size}]"
          
        end
        log.info "Finished processing #{batch}; failed: #{failed.size}, fixed (or valid): #{fixed.size}"
      
        # 5. Save (if --really)
        if true == really
          if fixed.any?
            if "" == client.username or "" == client.password
              log.warn "Missing HTTP username or password for #{uri}, set these in ENV[\"NPOLAR_API_USERNAME\"] and ENV[\"NPOLAR_API_PASSWORD\"]"
            end
            
            response = client.post("", fixed.to_json)
            
            if 201 == response.status
              log.info "Successful POST of fixed documents to #{uri} :)"
            else
              log.fatal "HTTP error #{response.status} when attempting to POST back fixed documents to #{uri}\n#{response.body}"
            end
          end
        end
        
        if fixed.any? and false == really
          log.info "Not publishing fixes to #{uri} --really was false"
        end

        # Fixes to STDOUT
        puts fixed.to_json
 
      end

      def valid?(document)
        client.valid? document
      end


    end
  end
end