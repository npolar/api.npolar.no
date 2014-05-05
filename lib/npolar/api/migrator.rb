require "digest/sha1"
module Npolar
  module Api

    class Migrator
      attr_accessor :client, :migrations, :log, :batch, :uri
      attr_writer :select, :documents
      
      def self.documents(client)
        lambda {|client| client.all }
      end

      def documents
        @documents ||= self.class.documents(client)
      end

      def select
        @select ||= lambda {|d| true }
      end
      
      def run(really=false)
        log.info "#{self.class.name}#run #{uri} [Migrations: #{migrations.size}] --really=#{really}"      
        log.debug "Migrations: #{migrations}"

        # 1. Get (all) documents
        selected = documents.call(client).select(&select)
        log.info "#{selected.size} documents selected of #{client.ids.size} at #{uri}"

        fixed = []
        failed = []
        unaffected = []
        
        selected.each_with_index do |d,j|
        

          
          valid?(d)
          log.debug "Errors before: #{client.errors(d).to_json}\n#{d.to_json}"

          # 2. Get all migrations
          i = 0
          migrations.each do |condition, fixer|
            if i == 0
              before = d.dup.to_hash
              @before_sha1 = Digest::SHA1.hexdigest(before.to_json)
            end
            

            if fixer.nil? 
              fixer = condition
              condition = lambda {|d| true }
            end
            
            i += 1
            if condition.call(d)
      
              # 3. Apply fix directly to document (for the next fixer)
              d = Hashie::Mash.new(fixer.call(d))
              log.debug "#{" "*2}Migration #{i}/#{migrations.size} for #{d.id}"
                      
            else
              log.debug "#{" "*2}Document #{d.id} not selected by condition #{condition}: [migration #{i}/#{migrations.size}]"
            end
          end

          # 4. Validate document
         
          after_sha1 = Digest::SHA1.hexdigest(d.dup.to_hash.to_json)
                    
          if @before_sha1 != after_sha1
            
            if valid?(d)
              
              fixed << d
              
              log.info "[#{fixed.size}] fixed #{d.id} "
              log.debug "Fixed: #{d.to_json}"
             
            else
              
              failed << d
              
              log.info "[#{failed.size}] failed #{d.id} "
              log.error "Failed migrating #{d.id}, errors: #{client.errors(d).to_json}\n#{d.to_json}"
              
            end
            log.info "="*80
            
          else
            unaffected << d
          end
          log.debug "Finished document #{d.id} [##{j+1}/#{selected.size}]"
          
        end
        log.info "Finished processing #{batch}; failed: #{failed.size}, fixed: #{fixed.size}, unaffected: #{unaffected.size}"
        log.debug "Unaffacted: #{unaffected.to_json}"
        # 5. Save (if --really)
        if true == really
          if fixed.any?
            if "" == client.username or "" == client.password
              log.warn "Missing HTTP username or password for #{uri}, set these in ENV[\"NPOLAR_API_USERNAME\"] and ENV[\"NPOLAR_API_PASSWORD\"]"
            end
            log.info "About to POST #{fixed.size} fixed documents back to #{uri}"
            client.uri = URI.parse(uri)
            response = client.post(fixed)
            
            if response.is_a? Array
              responses = response
            else
              responses = [response]
            end
            
            statuses = responses.map {|r| r.status }
            log.info "HTTP response status(es): #{statuses}"

            if statuses.all? {|s| (200..299).include? s }
              log.info "Successful re-POST of fixed documents to #{uri} :)"
            else
              log.error "Error responses: #{responses.reject {|r| (200..299).include? r.status }.map {|r|r.body} }"
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
        client.valid?(document)
      end


    end
  end
end