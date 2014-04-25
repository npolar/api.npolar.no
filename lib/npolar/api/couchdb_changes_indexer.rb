require "logger"
require "optparse"

require "eventmachine"
require "em-http"
require "yajl"
require "elasticsearch"


require_relative "../../../load"
require "npolar/api/client"

require_relative "../validation"
require_relative "../../service"

module Npolar
  module Api 
    class CouchdbChangesIndexer
      
      CMD = "npolar-api-couchdb-changes-indexer"
      
      PARAM = { :log => STDERR, :slice => 1000 }
      
      attr_accessor :param, :log, :service
      
      def initialize(service = nil)
        unless service.nil?
          @service = service
        end
      end
      
      def run

        buffer = []
        
        param[:slice] = param[:slice].to_i
        
        couchdb = URI.parse(ENV["NPOLAR_API_COUCHDB"])
        couchdb.path = "/"+service.database
    
        EM.run{
        
          Signal.trap("INT"){EM.stop}
          Signal.trap("TERM"){EM.stop}
        
          parser = Yajl::Parser.new(:symbolize_keys => true)
          parser.on_parse_complete = lambda{|json| buffer << json}
        
          http = EventMachine::HttpRequest.new(
            "#{couchdb}/_changes?feed=continuous&heartbeat=1000&since=0&include_docs=true",
              :connection_timeout => 0,
              :inactivity_timeout => 0
          ).get
          
          keepalive = 0
          http.stream do |chunk|
            begin 
              keepalive = chunk.match(/^r?\n$/) ? keepalive + 1 : 0
            rescue
              keepalive = 0
            end
            parser << chunk
        
            if buffer.size == param[:slice] || keepalive >= 2
              if buffer.size > 0
                batch = buffer.shift(param[:slice])
                indexer.call(batch)
              end
            end
          end
        
          http.errback {log.error "#{http.error}" ;EM.stop}
          http.callback {
            log.fatal "Stream finished"
            EM.stop
            # here the last seq should be persisted for restartof indexing at sa
            }
        }

      end
      
      def indexer
        log.debug "Indexing #{service.search.engine}"
        case service.search.engine
          when /Solr/
            lambda {|changes|
              
              config = service.search
              
              uri = config.uri? ? config.uri : config.core
              
              unless uri =~ URI::REGEXP
                uri = URI.parse(ENV["NPOLAR_API_SOLR"])
                uri.path = uri.path.gsub(/\/$/, "") + "/" + config.core
                uri = uri.to_s
              end

              log.debug "Solr #{uri} indexing #{changes.size} documents"
              
              updates = changes.select {|c|
                c.key?(:doc) and
                c.key?(:id) and
                c[:id] !~ /_design\//
              }
              
              # Index
              docs = updates.select {|u| u[:deleted].nil? or u[:deleted] != true }.map {|d| d[:doc]}
             
              if !docs.nil? and !docs.empty? 
                if service.model?
                  log.debug "Mapping to Solr using #{service.model}#to_solr"
                  docs.map! {|d|
                    m = Npolar::Factory.constantize(service.model).new(d)
                    m.to_solr
                    
                    }
                end
                
                
                client = Npolar::Api::Client::JsonApiClient.new
                responses = client.post(docs, "#{uri}/update")
                
                # @todo POST errors
                # @todo DELETE, must match /get?id=id revision, see http://wiki.apache.org/solr/RealTimeGet
                log.debug "Responses: #{responses.map {|r| r.code}}"
              end
            
            }

          when /Elasticsearch/
            lambda {|changes |
              
              
              changes.select! {|e| e.key?(:id)}
              config = service.search
              
              url = config.uri? ? config.uri : config.url
              
              log.debug "#{url} indexing #{changes.size} documents"
              
              idx = config[:index]
              type = config.type
              
              #changes.map! do |e|
              #  operation = e[:deleted] ? :delete : :index
              #  { operation => {:_index => idx, _type: type, _id: e[:id], data: e[:doc] } }
              #end
              #
              #changes.map! do |e|
              #  if e[:deleted]
              #    {:delete => {:_index => search[:index], :_type => search.type, :_id => e[:id], :ignore => 404}}
              #  else
              #    {:index => {:_index => search[:index], :_type => search.type, :_id => e[:id], :data => e[:doc]}}
              #  end
              #end
              updates = changes.select {|c|
                c.key?(:doc) and
                c.key?(:id) and
                c[:id] !~ /_design\//
              }
              
              # Index
              docs = updates.select {|u| u[:deleted].nil? or u[:deleted] != true }.map {|d| d[:doc]}
              uri = URI.parse(url)
              uri.path = "/#{idx}/#{type}"
              log.debug uri.to_s
              client = Npolar::Api::Client::JsonApiClient.new(uri.to_s)
              client.slice=1
              docs.each do |d|
                
              responses = client.post(d.to_json)
              end
              #responses = client.post(docs, "#{url}")
              
              # @todo POST errors
              # @todo DELETE, must match /get?id=id revision, see http://wiki.apache.org/solr/RealTimeGet
              responses = []
              
              log.debug "Responses: #{responses.map {|r| r.code}}"
              
              #puts changes.to_json
              #client = Elasticsearch::Client.new({url: url})
              #client.bulk :body => changes
              
            }
          else
            lambda {|changes| raise "Cannot index: #{service.search.engine}" }
        end
        
      end
      
      def self.param(argv)
        param = PARAM
        option_parser = OptionParser.new(argv) do |opts|
            opts.version = Npolar::Api::Client::VERSION
            opts.banner = "#{CMD} [options] /endpoint
Options:\n"

          opts.on("--slice", "-s=number", "Slice size") do |slice|
            param[:slice] = slice.to_i
          end
        end
        option_parser.parse!
        param
      end
      
      def self.run(argv=ARGV)
        
        begin
        
          indexer = new
          
          param = param(argv)
          indexer.param = param
          
          log = Logger.new(param[:log])
          indexer.log = log
        
          endpoint = argv[0]
          
          unless endpoint =~ URI::REGEXP
            base = URI.parse(ENV["NPOLAR_API"])
            base.path = endpoint
            endpoint = base.to_s
          end
          base = URI.parse(endpoint).host
          path = URI.parse(endpoint).path
          indexer.service = Service.services.select {|s| s.path == path }[0]
          
          log.debug "#{CMD} #{endpoint} #{indexer.service.model}"
          indexer.run
          log.info "#{CMD} finished"
          
        rescue => e
          puts e
          puts e.backtrace.join("\n")
          exit(1)
        end
      end

    end
  end
end
