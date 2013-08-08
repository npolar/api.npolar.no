require "hashie/mash"
require "rack/builder"

module Npolar
  module Api

    class Search

      def initialize(api, config={})
  
        @config = Hashie::Mash.new(config)
        @app = ::Rack::Builder.new do
          map "/" do

            model = nil
            if api.model?
              model = Npolar::Factory.constantize(api.model).new
            end
            
            if api.search? and api.search.engine?
        
              bootstrap = Bootstrap.new
              search = { :search => bootstrap.apis.select {|svc| svc.path != api.path }.map {|svc|
                  { :href => (svc.search? and svc.search.engine != "") ? svc.path+"/?q=" : svc.path+"/_ids.json",
                    :text => svc.path, :title => (svc.search? and svc.search.engine != "") ? "#{svc.path} search" : "#{svc.path} identifiers" }
                }
              }

              use Views::Api::Index, {:svc => search}

              if /Solr/i =~ api.search.engine
                
                run Npolar::Rack::Solrizer.new nil,{
                  :core => api.search.core,
                  :force => api.search.force,
                  :path => api.path,
                  :facets => api.search.facets
                }
              elsif /Elasticsearch/i =~ api.search.engine

                run Npolar::Rack::Icelastic.new nil, {
                  :uri => api.search.uri,
                  :index => api.search["index"],
                  :type => api.search.type,
                  :facets => api.search.facets,
                  :date_facets => api.search.date_facets,
                  :filters => api.search.filters
                }
              end
  
            end

          end
        end
      end

      def middleware(builder)

        ::Rack::Builder.new do

          map "/"
          
        end
      end
      
      def call(env)
        @app.call(env)
      end

    end
  end
end