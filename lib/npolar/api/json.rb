require "hashie/mash"
require "rack/builder"

module Npolar
  module Api
    
    # JSON lego set: A complete kit for running JSON APIs
    class Json


      # # config.ru - simple example
      # services = [Service.factory("service1.json"), Service.factory("service2.json")]
      # services.select { |api| ("http://data.npolar.no/schema/api" == api.schema)}.each do |api|
      #   if api.run =~ /(Npolar::Api::)?Json$/ and api.valid?
      #     map api.path do
      #       run Npolar::Api::Json.new(api)
      #     end
      #   end
      # end

      def initialize(api, config={})

        @config = Hashie::Mash.new(config)
        @app = ::Rack::Builder.new do
          map "/" do

            if api.model?
              model = Npolar::Factory.constantize(api.model).new
              # This will trigger NameError if model is undefined

            else
              model = nil
            end
            
            if api.storage?

              # todo if not Couch => WARN

              storage, database = api.storage, api.database
              storage = Npolar::Storage::Couch.new(database)
              storage.model = model
            end
            
            if api.auth?
              auth = api.auth
        
              # Open => open data => GET, HEAD are excepted from Authorization 
              except = api.open? ? lambda {|request| ["GET", "HEAD"].include? request.request_method } : false

              authorizer = case api.auth.authorizer
                when /Ldap/i then Npolar::Auth::Ldap.new(Npolar::Auth::Ldap.config)
                else Npolar::Auth::Couch.new(Service.factory("user-api.json").database)
              end

              use Npolar::Rack::Authorizer, { :auth => authorizer,
                :system => auth.system,
                :except? => except
              }
            end

            if api.middleware? and api.middleware.is_a? Array
              raise "Not implemented"
            end

            if api.search? and api.search.engine?
        
              use Views::Api::Index
                
              if "Solr" == api.search.engine
                
                use Npolar::Rack::Solrizer, {
                  :core => api.search.core,
                  :force => api.search.force,
                  :path => api.path,
                  :facets => api.search.facets
                }
              elsif "Elastic" == api.search.engine
                use Npolar::Rack::Icelastic, {
                  :uri => api.search.uri,
                  :index => api.search.index,
                  :type => api.search.type,
                  :facets => api.search.facets,
                  :date_facets => api.search.date_facets,
                  :filters => api.search.filters
                }
              end
  
            end

            before = [Npolar::Api::Json.before_lambda]
            after = [Npolar::Api::Json.after_lambda]
            
            if api.before?
              name, met = api.before.split(".")
              bef = Npolar::Factory.constantize(name)
              before << bef.send(met.to_sym)
            end

            if api.after?
              name, met = api.after.split(".")
              aft = Npolar::Factory.constantize(name)
              after << aft.send(met.to_sym)
            end

            run Core.new(nil,
              {:storage => storage,
              :formats => api.formats.keys, #hmm
              :methods => api.verbs,
              :accepts => api.accepts.keys,
              :before => before,
              :after => after}
            )

          end
        end
      end
      
      def call(env)
        @app.call(env)
      end

      # Adds "published" "updated" "author" "editor" before POST/PUT
      def self.before_lambda
        lambda {|request|
          
          if ["POST", "PUT"].include? request.request_method and "application/json" == request.media_type
              body = request.body.read
              begin

                d = Hashie::Mash.new(JSON.parse body)                
                d.updated = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ") #DateTime.now.xmlschema
                
                unless d.published?
                  d.published = d.updated
                end
                unless d.author?
                  d.author = request.username
                end
                unless d.editor?
                  d.editor = request.username
                end
                
                request.env["rack.input"] = StringIO.new(d.to_json)

              rescue JSON::ParserError
                # Crap JSON, don't do anyting
              end
          end
          request
        }  
      end

      def self.after_lambda
        lambda {|request, response|
          response
        }
      end
    end
  end
end