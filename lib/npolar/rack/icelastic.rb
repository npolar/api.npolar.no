module Npolar
  module Rack
    
    # [Functionality]
    #   Icelastic is a middleware that exposes elasticsearch on a RACK endpoint.
    #   On GET requests it translates request parameters into the correct elasticsearch
    #   syntax and uses them to query the configured elasticsearch index.
    #
    # [Authors]
    #   - Ruben Dens
    #
    # [Links]
    #   @see http://www.elasticsearch.org/guide/reference/api/search/ Elasticsearch search Documentation
    
    class Icelastic < Npolar::Rack::Middleware

      attr_accessor :env
      
      CONFIG = {
        :searcher => 'http://localhost:9200/',
        :index => 'global',
        :type => nil,
        :fields => nil,
        :start => 0,
        :limit => 25,
        :facets => nil,
        :date_facets => nil,
        :filters => nil,
        :sort => nil
      }

      def condition?(request)
        ['GET','HEAD'].include?(request.request_method) and !request.params.select{|k,v| k.match(/q(\-.*)?/)}.empty?
      end
      
      def handle(request)
        client = Npolar::ElasticSearch::Client.new(request, config)
        client.search
      end
      
    end
  end
end
