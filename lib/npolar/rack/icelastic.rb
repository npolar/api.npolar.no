module Npolar
  
  # [Functionality]
  #   IceLastic is a middleware that provides elasticsearch on a RACK endpoint.
  #   On GET requests it translates request parameters into the correct elasticsearch
  #   syntax and uses them to query the configured elasticsearch index.
  #
  # [Authors]
  #   - Ruben Dens
  #
  # [Links]
  #   @see http://www.elasticsearch.org/guide/reference/api/search/ Elasticsearch search Documentation
  
  module Rack
    class IceLastic < Npolar::Rack::Middleware
      
      CONFIG = {
        :searcher => 'http://localhost:9200/',
        :index => 'global',
        :type => nil,
        :fields => nil,
        :df => '_all',
        :start => 0,
        :limit => 50,
        :facets => []
      }
      
      def condition?(request)
        ['GET','HEAD'].include?(request.request_method) and request['q']
      end
      
      def handle(request)

        self.params = request.params
        params['start'] ? self.from = params['start'] : self.from = config[:start]
        params['limit'] ? self.size = params['limit'] : self.size = config[:limit]

        response = searcher.post do |req|
          req.url "/#{config[:index]}/#{config[:type]}/_search"
          req.headers['Content-Type'] = 'application/json'
          req.body = query
        end
        
        [200, {'Content-Type' => 'application/json'}, ["#{response.body}"]]
      end
      
      def searcher
        Faraday.new(:url => config[:searcher]) do |faraday|
          faraday.request  :url_encoded             # form-encode POST params
          faraday.response :logger                  # log requests to STDOUT
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end
      end
      
      def params=request_params
        @params = request_params
      end
      
      def params
        @params ||= {'q' => '*'}
      end
      
      def size=limit
        @size = limit
      end
      
      def size
        @size ||= config[:limit]
      end
      
      def from
        @from ||= config[:start]
      end
      
      def from=start
        @from = start
      end
      
      def query
        {
          'from' => from,
          'size' => size,
          'query' => {
            'query_string' => {
              'default_field' => config[:df],
              'query' => params['q']
            }
          },
          'facets' => facets
        }.to_json
      end
      
      def facets
        facet_query = {}
        
        config[:facets].each do |facet|
          facet_query[facet] = {
            'terms' => {
              'field' => "#{facet}"
            }
          }
        end
        
        facet_query
      end
      
    end
  end
end
