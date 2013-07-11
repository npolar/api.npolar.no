module Npolar
  module ElasticSearch
    class Client
      
      CONFIG = {
        :searcher => "http://localhost:9200",
        :index => "",
        :type => "",
        :start => 0,
        :limit => 25
      }
      
      attr_accessor :request, :config
      
      def initialize(request, config = {})
        self.request = request
        self.config = CONFIG.merge(config)
      end
      
      def search
        query = Npolar::ElasticSearch::Query.new(config)
        query.params = request.params
        query = query.build
        
        response = http.post do |req|
          req.url "/#{config[:index]}/#{config[:type]}/_search"
          req.headers['Content-Type'] = 'application/json'
          req.body = query
        end
        
        result = Npolar::ElasticSearch::Result.new(request, response)
        if request.params['format'] && request.params['format'] == 'csv'
          feed = result.to_csv
        else
          feed = result.to_feed
        end
        headers = {"Content-Type" => "application/json","Content-Length" => feed.bytesize}
        Rack::Response.new(feed, 200, headers)
      end
      
      protected
      
      def http
        Faraday.new(:url => config[:searcher]) do |faraday|
          faraday.request  :url_encoded             # form-encode POST params
          faraday.response :logger                  # log requests to STDOUT
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end
      end
      
    end
  end
end