module Npolar
  module ElasticSearch
    
    # [Functionality]
    #   This class provides some basic methods to manipulate search results comming
    #   from elasticsearch.
    #
    # @example
    #   results = Npolar::ElasticSearch::Result.new(search_request, search_response)
    #   feed = results.to_feed # Output a results feed @see #to_feed
    #   csv = results.to_csv # Output search results as a feed (works only with top lvl elements)
    #
    # [Authors]
    #   - Ruben Dens
    
    class Result
      
      attr_accessor :env, :request, :response, :body
      
      def initialize(request, response)
        self.request = request
        self.env = request.env
        
        self.response = response
        self.body = Yajl::Parser.parse(response.body)
      end
      
      # @see #feed
      def to_feed
        feed.to_json
      end
      
      # Create a generic feed structure from the raw search response
      def feed
        {
          :feed => {
            :opensearch => {
              :totalResults => total_hits,
              :itemsPerPage => page_items,
              :startIndex => start
            },
            :list => {
              :self => self_uri,
              :next => next_uri,
              :previous => previous_uri,
              :first => start.to_i,
              :last => last
            },
            :search => {
              :qtime => query_time,
              :q => query_term
            },
            :facets => facets,
            :entries => entries
          }
        }
      end
      
      # Create a csv representation of the search response
      def to_csv
        csv = CSV.generate("", {:col_sep => "\t"}) do |csv|
          
          entries = feed[:feed][:entries]
          fields = entries.first.keys
          
          csv << fields.map{|f| f.capitalize}
          entries.each do |entry|
            row = []
            fields.each{|field| row << entry[field]}
            csv << row
          end
        end
        
        csv
      end
      
      protected
      
      def facets
        if body.has_key?('facets') && !body['facets'].nil? && !body['facets'].empty?
          
          body['facets'].map do |facet, value|
            if value.has_key?('terms')
              {
                facet => value['terms'].map do |term|
                  {
                    :term => term['term'],
                    :count => term['count'],
                    :uri => facet_uri(facet, term['term'])
                  }
                end
              }
            elsif value.has_key?('entries')
              {
                facet => value['entries'].map do |entry|
                  
                  range_start = entry['time']
                  
                  sformat, range_end = case facet.split('-').first
                  when 'day' then ['%Y-%m-%d', next_utc_range_milliseconds(range_start, 'day')]
                  when 'week' then ['%Y-%m-%d', next_utc_range_milliseconds(range_start, 'week')]
                  when 'month' then ['%Y-%m', next_utc_range_milliseconds(range_start, 'month')]
                  when 'year' then ['%Y', next_utc_range_milliseconds(range_start, 'year')]
                  when /(\d{1,2}h)/ then ['%Y-%m-%dT%H:%M:%SZ', next_utc_range_milliseconds(range_start, $1)]
                  end    
  
                  {
                    :term => human_time(range_start, sformat),
                    :count => entry['count'],
                    :uri => facet_uri(
                      facet.split('-').last,
                      "#{human_time(range_start, sformat)}..#{human_time(range_end, '%Y-%m-%dT%H:%M:%SZ')}"
                    )
                  }
                end
              }
            end
          end
          
        end
      end
      
      # Build the uri for a facet
      def facet_uri(facet, term)
        t = term
        uri = self_uri.gsub(/&start=\d+/, '')
        
        if uri =~ /&filter-#{facet}=(.*)(&.*)?$/
          dmatch = $1
          t = dmatch.match(/#{term}/) ? dmatch.gsub(/#{term}/, term.to_s) : "#{dmatch},#{term}"
        end
        
        uri.gsub!(/&filter-#{facet}=(.*)/, "") # Remove any previous filters
        uri = "#{uri}&filter-#{facet}=#{t}" # Add filter
      end
      
      # Calculate the utc time in milliseconds given a certain start and range
      def next_utc_range_milliseconds(milliseconds, range)
        year = Time.at(milliseconds/1000).year
        month = Time.at(milliseconds/1000).month
        day = Time.at(milliseconds/1000).day
        
        next_value = case range
        when 'year' then Date.new(year, month, day).next_year
        when 'month' then Date.new(year, month, day).next_month
        when 'week' then Date.new(year, month, day).next_day(7)
        when 'day' then Date.new(year, month, day).next_day
        when /(\d{1,2})h/ then Time.utc(year, month, day, $1)
        end
        
        next_value = next_value.is_a?(Date) ? (Time.utc(next_value.year, next_value.month, next_value.day).to_i * 1000) : (next_value.to_i * 1000)
      end
      
      # Convert millisecond time to a human readable format
      def human_time(milliseconds, format = '%Y-%m-%dT%H:%M:%SZ')
        Time.at(milliseconds/1000).utc.strftime(format)
      end
      
      # Get the enries from the search results
      def entries
        body['hits']['hits'].map{|hit| hit['_source'] ? hit['_source'] : hit['fields']}
      end
      
      # The query term. If blank a wildcard is used
      def query_term
        params.has_key?('q') ? params['q'] : '*'
      end
      
      # Returns the search time from the result body
      def query_time
        body['took']
      end
      
      # Return the query string with the right start parameter
      def start_param(page_number)
        qp = env['rack.request.query_string']
        qp =~ /&start=(\d+)/ ? qp.gsub(/&start=(\d+)/, "&start=#{page_number}") : qp << "&start=#{page_number}"
      end
      
      # The uri for the current request
      def self_uri
        "http://#{env['HTTP_HOST'] + env['REQUEST_PATH']}?#{env['rack.request.query_string']}"
      end
      
      # The uri for the next batch of search results
      def next_uri
        next_page == false ? false : "http://#{env['HTTP_HOST'] + env['REQUEST_PATH']}?#{start_param(next_page)}" 
      end
      
      # The uri for the previous batch of search results
      def previous_uri
        previous_page == false ? false : "http://#{env['HTTP_HOST'] + env['REQUEST_PATH']}?#{start_param(previous_page)}"
      end
      
      # Total number of search results matching the query
      def total_hits
        body['hits']['total']
      end
      
      def page_items
        limit > total_hits ? total_hits : limit
      end
      
      # Index of the last item on the page
      def last
        return next_page - 1 unless next_page == false
        total_hits
      end
      
      # The limit paramter
      def limit
        params.has_key?('limit') ? params['limit'].to_i : 25
      end
      
      # The start parameter
      def start
        params.has_key?('start') ? params['start'].to_i : 0
      end
      
      # Value indicating from which result the next page starts
      # if no next page is available it returns false
      def next_page
        val = start.to_i + limit.to_i
        val < total_hits ? val : false
      end
      
      # Value indicating from which result the previous page starts
      # if no previous page is available it returns false
      def previous_page
        val = start.to_i - limit.to_i
        if val >= 0
          val
        else
          start.to_i > 0 ? 0 : false
        end
      end
      
      # The request parameter hash
      def params
        request.params
      end
      
    end
  end
end