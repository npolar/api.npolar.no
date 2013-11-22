# encoding: utf-8
require "yajl/json_gem"
require "hashie/mash"
require "date"
module Npolar

  module Api

    # A commanmdline utility class for counting documents and cross-checking
    # complete id sets between primary storage and search engine
    #
    # Run with bin/npolar_api_status
    # Should be refactored/generalized to accept objects with 4 methods:
    # count, ids, updated, ping
    class StatusCommand 

      PARAM = { action: :counts, level: Logger::INFO, uri: "http://api.npolar.no" }

      attr_accessor :param, :log, :api, :uri, :host

      def initialize(argv=ARGV, param = PARAM)
        @param = param

        option_parser = OptionParser.new(ARGV) do |opts|
    
          opts.on("--dsn", "-d", "Data source name") do |dsn|
            @param[:dsn] = dsn
          end

          opts.on("--level=LEVEL", "-l=LEVEL", "Log level") do |level|
            @param[:level] = Command.level(level)
          end

          opts.on("--action=ACTION", "-a=Action", "Action") do |action|
            @param[:action] = case action
              when "counts", "count_all"
                :counts
              when "count"
                :count
              when "missing"
                :missing
              else param[:action].to_sym
            end
          end
        
        end
        option_parser.parse!
        @uri = ARGV[0]||= param[:uri]
        if @uri !~ /^http(s)?[:]/
          @uri = "http://#{uri}"
        end
        
        @host = URI.parse(uri).host
        @log = Logger.new(STDERR)
        @log.progname = self.class.name
        @log.level = param[:level]

      end

      def uri
        @uri
      end

      def self.apis(uri)
         @apis ||= begin
          client = Client.new(uri)
          client.get_body("/service/_feed.json?fields=*").select {|api|
            api }.map {|api| Hashie::Mash.new(api)}
        end
      end

      def self.apis=(apis)
        @apis=apis
      end

      def self.dsn(uri, api)

        if api.storage !~ /Couch(DB)?/
          #raise "Not supported storage: \"#{api.storage}\""
        end
        
        dbhost = case uri.host
          when "api.npolar.no"
            "dbmaster.data.npolar.no"
          when "apptest.data.npolar.no"
            "dbtest.data.npolar.no"
          else
            URI.parse(ENV["NPOLAR_API_COUCHDB"]).host
          end

        uri.host = dbhost
        uri.port = dbhost == "dbmaster.data.npolar.no" ? 5984 : 5984
        uri.path = "/#{api.database}"
        uri.scheme = dbhost == "dbmaster.data.npolar.no" ? "http" : "http"
        uri.to_s
      end

      def self.search_uri(uri, api)
        if api.search.nil? or api.search.engine.nil?
          return nil
        end
        dsn = dsn(uri, api)
        host = URI.parse(dsn).host
        if api.search.engine =~ /Elastic/i
          port = 9200
          path = "/"+api[:search][:index]
          if not api[:search][:type].nil?
            path += "/"+api[:search][:type]
          end
        else
          port = 8983
          if api.search.core =~ /^http(s)?[:]/
            return api.search.core
          end
          
          path = "/solr/#{api.search.core}"
        end
        uri.port = port
        uri.host = host
        uri.path = path
        uri.scheme = "http"
        uri
      end

      def actions
        [:count, :counts, :missing, :ping]
      end

      def api
        @api ||= begin
          u = URI.parse(uri)
          apis = self.class.apis(uri).select {|api|
            api.path == u.path
          }
          if apis.size != 1
            raise "Invalid API #{uri}"
          end
          api = apis[0]
          log.info "#{uri} | Database: #{self.class.dsn(u, api)} | Search engine #{api.search.engine}"
          api
        end
      end

      def apis
        self.class.apis(uri)
      end

      def ids
        couch_ids
      end

      def count
        begin
          indexed_count = nil
  
          if api.search? and api.search.engine?
            indexed_count = case api.search.engine
            when /Solr/i
              solr_count
            else
              elasticsearch_count
            end
          end
  
          master = couch_count
          copy = indexed_count
          error = difference = nil
          if not master.nil? and not copy.nil?
            difference = (master-copy).abs
          end
        rescue => e
          log.error e
        end


        if master.nil? or copy.nil?
          error = false  
        else
        
          error = (difference != 0)
        end

        { :host => host, :path=> api.path,
          :database => { count: master, dsn: dsn, storage: api.storage },
          :search => { count: indexed_count, uri: search_uri },
          difference: difference, error: error,
          updated: DateTime.now.xmlschema }
      end

      def counts
        log.debug "Counting #{uri} documents"
        c = []
        begin
          apis.each do |api|
            log.debug api.path
              @api = api
              c << count
          end
        rescue => e
          log.error e
        end
        c
      end

      def couch_ids
        log.debug "Getting database ids from #{dsn}"
        client = Client.new(dsn)
        result = client.get_body("#{dsn}/_all_docs")
        log.info "#{result.total_rows} database ids retrieved from #{dsn}"
        result.rows.map {|r|r.id}
      end

      def couch_count
        log.debug "Getting Couch document count from #{dsn}"
        client = Client.new(dsn)
        c = client.get_body("#{dsn}").doc_count
        log.info "#{api.path} #{c} documents in #{dsn}"
        c
      end

      # @todo --dsn=
      def dsn        
        self.class.dsn(URI.parse(uri), api)
      end


      def elasticsearch_count
        log.debug "Counting #{api.search.engine} #{search_uri} documents"
        client = Client.new
        param = { query: { match_all: {} }, fields: [], from: 0, size: 0 }

        c = Hashie::Mash.new(JSON.parse(client.post("#{search_uri}/_search", param.to_json).body)).hits.total.to_i
        log.info "#{api.path} #{c} documents in #{api.search.engine} #{search_uri}"
        c
      end

      def elasticsearch_ids

        param = { query: { match_all: {} }, fields: [], from: 0, size: elasticsearch_count }

        body = Hashie::Mash.new(JSON.parse(client.post("#{search_uri}/_search", param.to_json).body))

        body.hits.hits.map {|r| r._id }
      end

      def indexed_ids
        case api.search.engine
        when /Solr/i
          solr_ids
        else
          elasticsearch_ids
        end
      end

      def missing
        missing = ids - indexed_ids
        log.info "#{missing.size} document(s) missing in Search engine #{search_uri}"
        missing
      end

      def run
        if actions.include? param[:action]
          send(param[:action])
        else
          raise ArgumentError, "Unknwon action: #{param[:action]}"
        end
      end

      # @todo --search-uri=
      def search_uri
        self.class.search_uri(URI.parse(uri), api)
      end

      def solr_ids
        count = solr_count
        
        param = {q: "*:*", facet: false, wt: "json", rows: count, fl: "id" }
        result = client.get_body("#{search_uri}/select", param)

        log.debug "Fetching #{api.search.engine} ids at #{search_uri}"
        result.response.docs.map {|r| r.id }
        
      end

      def solr_count
        log.debug "Counting #{api.search.engine} ids at #{search_uri}"
        client = Client.new
        param = {q: "*:*", facet: false, wt: "json", rows: 0, fl: "id" }
        result = client.get_body("#{search_uri}/select", param)

        rows = result.response.numFound
        log.info "#{rows} documents in #{search_uri}"
        rows
      end

    end
  end
end