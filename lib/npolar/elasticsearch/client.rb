module Npolar
  module ElasticSearch
    class Client

      CONFIG = {
        :uri => "http://localhost:9200/",
        :index => "",
        :type => "",
        :start => 0,
        :limit => 25
      }

      attr_accessor :request, :config, :log

      def initialize(request, config = {})
        self.request = request
        self.config = CONFIG.merge(config)
        self.log = ::Logger.new(STDERR)
      end

      def search
        query = Npolar::ElasticSearch::Query.new(config)
        query.params = request.params
        query = query.build

        response = http.post do |req|
          req.url "/#{config[:index]}/#{config[:type]}/_search"
          req.headers['Content-Type'] = 'application/json; charset=utf8'
          req.body = query
        end

        unless [500, 404].include?(response.status)
          result = Npolar::ElasticSearch::Result.new(request, response)

          if request.params['format'] && request.params['format'] == 'csv'
            feed = result.to_csv
          else
            feed = result.to_feed
          end

          headers = {"Content-Type" => "application/json; charset=utf8","Content-Length" => feed.bytesize}
          Rack::Response.new(feed, 200, headers)
        else

          response = case response.status
            when 404 then Rack::Response.new('Search engine not found', 404, {"Content-Type" => "text/plain; charset=utf8"})
            when 500 then Rack::Response.new('Search engine error', 500, {"Content-Type" => "text/plain; charset=utf8"})
          end

        end
      end

      def index( data )
        if data.is_a?( Array )
          log.info "Npolar::Elasticsearch::Client - Attempting to save #{data.size} documents to the #{config[:index]} index"
          store = Npolar::ElasticSearch::BulkRequest.new(data, config)
          store.execute
        else
          #puts data
          log.info "Npolar::Elasticsearch::Client - Indexing 1 document"
          store = Npolar::ElasticSearch::BulkRequest.new( [data], config )
          store.execute
        end
      end

      protected

      def http
        Faraday.new(:url => config[:uri]) do |faraday|
          faraday.request  :url_encoded             # form-encode POST params
          faraday.response :logger                  # log requests to STDOUT
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end
      end

    end
  end
end
