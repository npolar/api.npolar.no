require 'logger'

module Search
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
    #     - @param :name is the name the facet is returned with
    #     - @param :field is the data field to facet on
    #   @example: &facet-research-topics=topic
    #
    # [Filtering]
    #   filter-term=value:
    #     - @param :term is the field you want to filter on
    #     - @param :value is the field you want to filter for
    #   @example &filter-topic=biology
    #
    # [Authors]
    #   - Ruben Dens
    
    class Query
      
      def initialize(configuration = {})
        
        if configuration.is_a?( Hash )
          self.config = configuration.select{ |k,v| configurable.include?(k) }
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
      
      def configurable
        [:start, :limit, :filters, :facets, :date_facets, :sort]
      end
      
      def build
        if params.select{|k,v| k.match(/^filter-(.*)/)}.empty? and !config.has_key?(:filters)
          body = { :query => query }
        else
          body = { :query => filtered_query }
        end
        
        body[:from] = from
        body[:size] = size
        body[:sort] = sort
        body[:facets] = facets
        body[:fields] = fields unless fields.nil?
        
        body.to_json
      end
      
      def from
        params['start'] ? params['start'].to_i : config[:start] ||= 0
      end
      
      def size
        params['limit'] ? params['limit'].to_i : config[:limit] ||= 25
      end
      
      # Date facets @see {http://www.elasticsearch.org/guide/reference/api/search/facets/date-histogram-facet/ Date histogram}
      def dfacets
        
      end
      
      def facet_params
        fp = params.select{|k, v| k.match(/^facet-(.*)/)}
        fp.merge!(config[:facets]) if config[:facets]
        fp
      end
      
      def facets
        fc = {}
        
        # Select facet parameters and map them to the proper structure
        # loop through the result array and merge them into the facet
        # hash that will be returned to the calling instance
        
        facet_params.map{ |k,v|
          {
            k.gsub(/facet-/,'') => {
              :terms => {
                :field => v
              }
            }
          }
        }.each{ |facet|
          fc.merge!(facet)
        }
        
        fc
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
        fp.merge!(config[:filters]) if config.has_key?(:filters) # Merge in configured filters
        
        fp
      end
      
      # Build a filter from the filter parameters @see {:filter_params}
      def filter
        {
          :and => filter_params.map{ |k,v|
            v.split(',').map{|value|
              unless value.match(/\-?\d+\.\.\-?\d+/)
                {
                  :term => {
                    k.gsub(/^filter-/, '') => value
                  }
                }
              else
                {
                  :range => {
                    k.gsub(/^filter-/, '') => {
                      :from => value.split('..').first,
                      :to => value.split('..').last
                    }
                  }
                }
              end
              
            }
          }.flatten
        }
      end
      
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
      
      def q_param
        if params.has_key?('q') && params['q'] != '*'
          params['q'].match(/(.*)(\s)+$/) ? "#{$1}*" : "#{params['q']}*"
        else
          params['q'] = '*'
        end
      end
      
      def sort
        sort_items = []
        
        if params['sort']
          sort_items = params['sort'].split(',').map{|item|
            item.match(/^\-(.*)/) ? {item[1..-1] => :desc} : {item => :asc}
          }
        end
        
        sort_items
      end
      
      def field_query
        {
          :query_string => params.select{|k, v|
            k.match(/^q-(.*)/)
          }.map{ |k,v|
            {
              :default_field => k.gsub(/^q-/, ''),
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