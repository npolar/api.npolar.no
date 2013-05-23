require 'logger'

module Search
  module ElasticSearch
  
    # [Functionality]
    #   This class is used to construct an elasticsearch qeury from a set of
    #   uri query parameters
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
      
      attr_accessor :config
      
      def initialize(configuration = {})
        if configuration.is_a?( Hash )
          self.config = configuration.select{ |k,v| configurable.include?(k) }
        else
          log.debug "Npolar::Search::ElasticSearch::Query : Configuration failed!
            Expecting a Hash but got |#{configuration.class}|. Falling back to presets."
        end
      end
      
      def configurable
        [:start, :limit, :filters, :facets, :date_facets, :sort]
      end

      def parse(query_parameters)
        self.params = query_parameters if query_parameters.is_a?(Hash)
      end
      
      def build
        if params.select{|k,v| k.match(/^filter-(.*)/)}.empty?
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
      
      def facets
        fc = {}
        
        # Select facet parameters and map them to the proper structure
        # loop through the result array and merge them into the facet
        # hash that will be returned to the calling instance
        
        params.select{|k, v|
          k.match(/^facet-(.*)/)
        }.map{ |k,v|
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
      
      def filter
        {
          :and => params.select{|k, v|
            k.match(/^filter-(.*)/)
          }.map{ |k,v|
            unless v.match(/\-?\d+\.\.\-?\d+/)
              {
                :term => {
                  k.gsub(/^filter-/, '') => v
                }
              }
            else
              {
                :range => {
                  k.gsub(/^filter-/, '') => {
                    :from => v.split('..').first,
                    :to => v.split('..').last
                  }
                }
              }
            end
          }
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