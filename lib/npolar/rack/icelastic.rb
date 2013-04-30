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
    class IcElastic < Npolar::Rack::Middleware
      
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
      
      attr_accessor :env
      
      def condition?(request)
        ['GET','HEAD'].include?(request.request_method) and request['q']
      end
      
      def handle(request)

        self.env = request.env

        self.params = request.params
        params['start'] ? self.from = params['start'] : self.from = config[:start]
        params['limit'] ? self.size = params['limit'] : self.size = config[:limit]
        params['fields'] ? self.fields = params['fields'] : self.fields = config[:fields]
        @params = {'q' => '*'} if params['q'].empty?

        log.info "QUERY: #{query}"

        response = searcher.post do |req|
          req.url "/#{config[:index]}/#{config[:type]}/_search"
          req.headers['Content-Type'] = 'application/json'
          req.body = query
        end
        
        results = Yajl::Parser.parse(response.body)
        results = generate_feed(results).to_json
        
        [200, {'Content-Type' => 'application/json'}, [results]]
      end
      
      def searcher
        Faraday.new(:url => config[:searcher]) do |faraday|
          faraday.request  :url_encoded             # form-encode POST params
          faraday.response :logger                  # log requests to STDOUT
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end
      end
      
      def generate_feed(results)
        
        {
          :feed => {
            :opensearch => {
              :totalResults => results['hits']['total'],
              :itemsPerPage => size,
              :startIndex => from
            },
            :list => {
              :self => "http://#{env['HTTP_HOST'] + env['REQUEST_PATH'] + env['rack.request.query_string']}",
              :next => next_page,
              :previous => previous_page,
              :first => from.to_i,
              :last => next_page - 1
            },
            :search => {
              :qtime => results['took'],
              :q => params['q']
            },
            :facets => results['facets'].map{|facet, value| {facet => value['terms']}},
            :entries => results['hits']['hits'].map{|hit| hit['_source'] ? hit['_source'] : hit['fields']}
          }
        }
        
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
      
      def fields=fields
        @fields = fields.split(',') unless fields.nil? || fields.empty?
      end
      
      def fields
        @fields ||= nil
      end
      
      def next_page
        val = from.to_i + size.to_i
      end
      
      def previous_page
        val = from.to_i - size.to_i
        val > 0 ? val : false
      end
      
      def query
        data = {
          'from' => from,
          'size' => size,
          'query' => {
            'query_string' => {
              'default_field' => config[:df],
              'query' => params['q']
            }
          },
          'facets' => facets
        }

        data['fields'] = fields unless fields.nil?
        
        data.to_json
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
