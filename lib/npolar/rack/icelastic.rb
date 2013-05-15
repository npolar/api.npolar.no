module Npolar
  
  # [Functionality]
  #   Icelastic is a middleware that provides elasticsearch on a RACK endpoint.
  #   On GET requests it translates request parameters into the correct elasticsearch
  #   syntax and uses them to query the configured elasticsearch index.
  #
  # [Authors]
  #   - Ruben Dens
  #
  # [Links]
  #   @see http://www.elasticsearch.org/guide/reference/api/search/ Elasticsearch search Documentation
  
  module Rack
    class Icelastic < Npolar::Rack::Middleware
      
      CONFIG = {
        :searcher => 'http://localhost:9200/',
        :index => 'global',
        :type => nil,
        :fields => nil,
        :df => '_all',
        :start => 0,
        :limit => 50,
        :facets => [],
        :date_facets => nil,
        :filter => nil,
        :sort => []
      }
      
      attr_accessor :params, :env, :total_hits

      def condition?(request)
        ['GET','HEAD'].include?(request.request_method) and request['q']
      end
      
      def handle(request)

        self.env = request.env
        self.params = request.params
        self.params ||= {:q => '*'}
        
        params['start'] ? self.from = params['start'] : self.from = config[:start]
        params['limit'] ? self.size = params['limit'] : self.size = config[:limit]
        params['fields'] ? self.fields = params['fields'] : self.fields = config[:fields]
        
        config[:sort] = params['sort'].split(',') if params['sort']
        config[:filter] = params['fq'].split(',') if params['fq']
        
        @params['q'] = '*' if params['q'].empty?

        log.info "ELASTIC QUERY: #{query}"

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
            :facets => results['facets'].map do |facet, value|
              if value.has_key?('terms')
                {
                  facet => value['terms'].map do |term|
                    {
                      :term => term['term'],
                      :count => term['count'],
                      :uri => if self_uri =~ /&fq=/
                        #delete the entire fq paramter
                        link = "#{self_uri.gsub(/&start=\d+/, '').gsub(/&fq=#{params['fq']}/,'')}"
                        #insert new fq parameter and replace duplicate
                        fq = params['fq'].gsub(/#{facet}:#{term['term']}(,)?/, '')
                        link = "#{link}&fq=#{facet}:#{term['term']}#{',' + fq unless fq.empty?}".gsub(/,$/, '')
                      else
                        "#{self_uri.gsub(/&start=\d+/, '')}&fq=#{facet}:#{term['term']}"
                      end
                    }
                  end
                }
              elsif value.has_key?('entries')
                {
                  facet => value['entries'].map do |entry|
                    
                    strf = '%Y-%m-%dT%H:%M:%SZ'
                    range_start = entry['time']
                    
                    strf, range_end = case facet
                    when 'hour' then [strf, Time.new()]
                    when 'day' then ['%Y-%m-%d', next_utc_range_milliseconds(range_start, 'day')]
                    when 'month' then ['%B-%Y', next_utc_range_milliseconds(range_start, 'month')]
                    when 'year' then ['%Y', next_utc_range_milliseconds(range_start, 'year')]
                    end    
                    
                    {
                      :term => Time.at(entry['time']/1000).strftime(strf),
                      :count => entry['count'],
                      :uri => "#{self_uri.gsub(/&start=\d+/, '').gsub(/&range=.*:\d+\|\d+/, '')}&range=#{config[:date_facets][:field]}:#{range_start}|#{range_end}"
                    }
                  end
                }
              end

            end,
            :entries => results['hits']['hits'].map{|hit| hit['_source'] ? hit['_source'] : hit['fields']}
          }
        }
        
      end
      
      def next_hour_utc_milliseconds(milliseconds)
        
      end
      
      def next_utc_range_milliseconds(milliseconds, range)
        year = Time.at(milliseconds/1000).year
        month = Time.at(milliseconds/1000).month
        day = Time.at(milliseconds/1000).day
        
        
        next_value = case range
        when 'year' then Date.new(year, month, day).next_year
        when 'month' then Date.new(year, month, day).next_month
        when 'day' then Date.new(year, month, day).next_day
        end
        
        next_value = (Time.utc(next_value.year, next_value.month, next_value.day).to_f * 1000).to_i
      end
      
      def to_csv(results)
        
        csv = CSV.generate("", {:col_sep => "\t"}) do |csv|
          csv << fields.map{|f| f.capitalize}
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
        qp = orig = env['rack.request.query_string']
        qp =~ /&start=(\d+)/ ? qp.gsub(/&start=(\d+)/, "&start=#{page_number}") : qp << "&start=#{page_number}"
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
          :from => from,
          :size => size,
          :query => {
            :filtered => {
              :query => {
                :query_string => {
                  :default_field => config[:df],
                  :query => params['q']
                }
              }
            }
          },
          :facets => facets,
          :sort => sort
        }

        data[:query][:filtered]['filter'] = filter unless filter.empty?
        data[:fields] = fields unless fields.nil?
        
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

        if config[:date_facets]
          config[:date_facets][:format].each {|format| facet_query[format] = {:date_histogram => {:field => config[:date_facets][:field], :interval => format}}}
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
        
        if params['range']
          range_filter.each do |filter|
            filtered_query['and'] ||= []
            filtered_query['and'] << filter
          end
        end
        
        filtered_query
      end
      
      def range_filter
        filters = []
        
        ranges = params['range'].split(',')
        
        ranges.each do |range|
          field, values = range.split(':')
          start, stop = values.split('|')
          
          filters << {
            :range => {
              field => {
                :from => start,
                :to => stop
              }
            }
          }
          
        end
        
        filters
      end
      
      def sort
        sorted_query = []
        
        config[:sort].each do |item|
          
          d = item.split(':')
          sorted_query << {d.first => d.last}
          
        end if config[:sort].any?
        
        sorted_query
      end
      
    end
  end
end
