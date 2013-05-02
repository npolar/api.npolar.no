module Npolar
  
  # [Functionality]
  #   IcELastic is a middleware that provides elasticsearch on a RACK endpoint.
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
        :facets => [],
        :filter => nil,
      }
      
      attr_accessor :env, :total_hits
      
      def condition?(request)
        ['GET','HEAD'].include?(request.request_method) and request['q']
      end
      
      def handle(request)

        self.env = request.env
        self.params = request.params
        
        params['start'] ? self.from = params['start'] : self.from = config[:start]
        params['limit'] ? self.size = params['limit'] : self.size = config[:limit]
        params['fields'] ? self.fields = params['fields'] : self.fields = config[:fields]
        
        if params['fq']
          unless params['fq'].split(':').any?
            config[:filter] = [params['fq']]
          else
            config[:filter] = params['fq'].split(',')
          end
        end
        
        @params['q'] = '*' if params['q'].empty?

        log.info "QUERY: #{query}"

        response = searcher.post do |req|
          req.url "/#{config[:index]}/#{config[:type]}/_search"
          req.headers['Content-Type'] = 'application/json'
          req.body = query
        end
        
        results = Yajl::Parser.parse(response.body)
        self.total_hits = results['hits']['total']
        results = generate_feed(results)
        
        if params['format'] == 'csv' && params['fields']
          results = to_csv(results) 
        else
          results = results.to_json
        end
        
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
              :totalResults => total_hits,
              :itemsPerPage => size,
              :startIndex => from
            },
            :list => {
              :self => self_uri,
              :next => next_uri,
              :previous => previous_uri,
              :first => from.to_i,
              :last => last
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
      
      def to_csv(results)
        
        csv = CSV.generate("", {:col_sep => "\t"}) do |csv|
          csv << fields.map{|f| f.capitalize}
          csv << []
          results[:feed][:entries].each do |entry|
            
            row = []
            
            fields.each{|field| row << entry[field]}
            
            csv << row
          end
        end
        
        csv
      end
      
      def self_uri
        "http://#{env['HTTP_HOST'] + env['REQUEST_PATH']}?#{env['rack.request.query_string']}"
      end
      
      def next_uri
        next_page == false ? false : "http://#{env['HTTP_HOST'] + env['REQUEST_PATH']}?#{start_param(next_page)}"
      end
      
      def previous_uri
        previous_page == false ? false : "http://#{env['HTTP_HOST'] + env['REQUEST_PATH']}?#{start_param(previous_page)}"
      end
      
      def start_param(page_number)
        qp = env['rack.request.query_string']
        qp =~ /&start=(\d+)/ ? qp.gsub!(/&start=(\d+)/, "&start=#{page_number}") : qp << "&start=#{page_number}"
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
        val < total_hits ? val : false
      end
      
      def previous_page
        val = from.to_i - size.to_i
        val >= 0 ? val : false
      end
      
      def last
        return next_page - 1 unless next_page == false
        total_hits
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
          'facets' => facets,
          'filter' => filter
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
      
      def filter
        filtered_query = {}
        
        config[:filter].each do |filter|
          
          terms = filter.split(':')
          
          filtered_query['and'] ||= []
          filtered_query['and'] << {:term => {terms.first => terms.last}}
        end if config[:filter]
        
        filtered_query
      end
      
    end
  end
end
