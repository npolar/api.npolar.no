require "hashie/mash"
require "rack/builder"

module Npolar
  module Api

#
#services = client.get_body("_all_docs", {"include_docs"=>true}).rows.map {|row|
#
#  Service.new(row.doc)
#
#}
#
#
#services.select {|api|
#  ( /^(Npolar::Api::)?Json$/ == api.run
#    and "http://data.npolar.no/schema/api" == api.schema) }.each_with_index do |api,i|
#  map api.path do
#
#    # merge in middleware from config files!
#
#    run Npolar::Api::Json.new(api)
#  end
#end


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
        
              use Views::Api::Index #, {:svc => search}

              if "Solr" == api.search.engine

                run Npolar::Rack::Solrizer.new(nil, { :core => api.search.core,
                  :force => api.search.force,
                  :facets => api.search.facets
                })
              elsif "Elastic" == api.search.engine
                raise "@todo"
              end
  
            end

          end
        end
      end
      
      def call(env)
        @app.call(env)
      end

    end
  end
end