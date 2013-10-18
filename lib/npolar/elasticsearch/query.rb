require 'logger'

module Npolar
  module ElasticSearch

    # [Functionality]
    #   This class is used to constructs a json query
    #   for Elasticsearch
    #
    # [Defaults]
    #   - start= defaults to 0
    #   - limit= defaults to 25
    #   - sort= defaults to ascending
    #
    # [Facets]
    #   facet-name=field:
    #     @param :name is the name the facet is returned with
    #     @param :field is the data field to facet on
    #
    # [Date Facets]
    #   Date facets are supported through the configuration.
    #   Look at the examples below for syntax
    #
    # [Filtering]
    #   filter-term=value:
    #     @param :term is the field you want to filter on
    #     @param :value is the field you want to filter for
    #
    # @example Query Examples
    #   Field query: http://api.npolar.no?q-title=polar
    #   Filtered query: http://api.npolar.no?q=&filter-topic=biology
    #   Faceted query: http://api.npolar.no?q=&facet-research-topics=topic
    #   Query bounds: http://api.npolar.no?q=&start=10&limit=60&sort=created
    #
    # @example Configuration
    #   #Date Facets
    #   config = {:date_facets => {:publication_year => {:field => :created, :interval => :day}}}
    #   Npolar::ElasticSearch::Query.new(config)
    #
    # @see #filter
    # @see #facets
    #
    # [Authors]
    #   - Ruben Dens

    class Query

      def initialize(configuration = {})
        self.params = params
        if configuration.is_a?( Hash )
          self.config = configuration.select{ |k,v| configurable.include?(k) && !v.nil? }
        else
          log.debug "Search::ElasticSearch::Query : Configuration failed!
            Expected a Hash but got |#{configuration.class}|. Falling back to defaults."
        end
      end

      def config=configuration
        @cfg = configuration
      end

      def config
        @cfg ||= {}
      end

      # List of valid configuration items
      def configurable
        [:start, :limit, :filters, :facets, :date_facets, :sort]
      end

      # Build an elasticsearch query body from the provided parameters and configuration
      def build
        if params.select{|k,v| k.match(/^filter-(.*)/)}.empty? and !config.has_key?(:filters)
          body = { :query => query }
        else
          body = { :query => filtered_query }
        end

        body[:highlight] = highlight
        body[:from] = from
        body[:size] = size
        body[:sort] = sort
        body[:facets] = facets unless facets.empty?
        body[:fields] = fields unless fields.nil?

        log.debug "Npolar::ElasticSearch::Query:\n#{JSON.pretty_generate(body)}"

        body.to_json
      end

      def from
        params['start'] ? params['start'].to_i : config[:start] ||= 0
      end

      def size
        params['limit'] ? params['limit'].to_i : config[:limit] ||= 25
      end

      def highlight
        {
          :fields => {
            "_all" => {"fragment_size" => 40, "number_of_fragments" => 4, "pre_tags" => ["<em class='bolder'>"], "post_tags" => ["</em>"]}
          }
        }
      end

      # Date facets are only supported through configuration
      # to define a date facet you provide this in a config hash
      # {:date_facets => { "year" => {"created" => "year"}, "published" => {} }
      # @see {http://www.elasticsearch.org/guide/reference/api/search/facets/date-histogram-facet/ Date histogram}

      def date_facets
        df = {}

        if config[:date_facets]
          config[:date_facets].each do |facet|
            df["#{facet['interval']}-#{facet['field']}"] = {
              :date_histogram => {
                :field => facet['field'],
                :interval => facet['interval']
              }
            }
          end
        end

        df
      end

      def facet_params
        fp = params.select{|k, v| k == 'facets' }.map{|k,v| v.split(',')}.flatten
        fp.concat(config[:facets]) if config[:facets]
        fp
      end

      def facets
        fc = {}

        facet_params.map{ |field|
          {
            field => {
              :terms => {
                :field => field,
                :size => 20
              }
            }
          }
        }.each{ |facet|
          fc.merge!(facet)
        }

        fc.merge!(date_facets)
      end

      def fields
        params['fields'] ? params['fields'].split(',') : nil
      end

      def filtered_query
        {
          :filtered => {
            :query => query,
            :filter => filter
          }
        }
      end

      # Gather all parameters and configuration items that define a filter
      def filter_params
        fp = params.select{|k, v| k =~ /^filter-(.*)/} # Grab filters from the query parameters
        config[:filters].each{|filter| fp.merge!(filter)} if config.has_key?(:filters) # Merge in configured filters
        fp
      end

      # Build a filter from the filter parameters
      # @see #filter_params
      def filter
        {
          :and => filter_params.map{ |k,v|
            # Remove any spaces from the filters
            #v.gsub!(/\s+/, ',') unless v =~ /\"(.*)\"/

            # Split and map to proper query
            v.split(',').map{|value|
              if value.match(/\-?\d+Z?\.\.\-?\d+/)
                vals = value.split('..')

                # Swap the values if the second one is bigger then the first
                unless value.match(/^\d{4}\-(\d{2})?\-?(\d{2})?T?(\d{2}):?(\d{2})?:?(\d{2})?Z?/)
                  unless vals[0].to_f < vals[1].to_f
                    vals[0], vals[1] = vals[1], vals[0]
                  end
                end

                {
                  :range => {
                    k.to_s.gsub(/^filter-/, '') => {
                      :from => vals.first,
                      :to => vals.last
                    }
                  }
                }
              elsif value =~ /\"(.*)\"/
                {
                  :query => {
                    :query_string => {
                      :default_field => k.to_s.gsub(/^filter-/, ''),
                      :query => value.gsub(/\"/,'').gsub(/\s+/, " AND ")
                    }
                  }
                }
              else
                {
                  :term => {
                    k.to_s.gsub(/^filter-/, '') => value
                  }
                }
              end

            }
          }.flatten
        }
      end

      # Returns the correct query type
      # @see #field_query
      # @see #query_string
      def query
        return field_query unless params.select{|k,v| k.match(/^q-(.*)/)}.empty?
        query_string
      end

      def query_string
        {
          :query_string => {
            :default_field => :_all,
            :query => q_param
          }
        }
      end

      # Query parameter q. If no q parameter is present it uses a wildcard.
      # If a q paramter is present it appends a wildcard to support fuzzy searches
      def q_param
        if params.has_key?('q') && params['q'] != '*'
          q = CGI.escape(params['q'].strip)
          q == "" ? "*" : "#{q} #{q}*"
        else
          params['q'] = '*'
        end
      end

      def sort
        sort_items = []

        if params['sort']
          sort_items = params['sort'].split(',').map{|item|
            if item.match(/^\-(.*)/)
              {
                item[1..-1] => {
                  :order => :desc,
                  :ignore_unmapped => true
                }
              }
            else
              {
                item => {
                  :order => :asc,
                  :ignore_unmapped => true
                }
              }
            end
          }
        end

        sort_items
      end

      # Build a query to match a specific data field
      def field_query
        {
          :query_string => params.select{|k, v|
            k.match(/^q-(.*)/)
          }.map{ |k,v|
            {
              :default_field => k.to_s.gsub(/^q-/, ''),
              :query => v
            }
          }.first
        }
      end

      def params=(parameters)
        @params = parameters
      end

      def params
        @params ||= {'q' => '*'}
      end

      protected

      def log
        Logger.new(STDERR)
      end

    end
  end
end
