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
              storage, database = api.storage, api.database

              storage = Npolar::Storage::Couch.new(database) # Factory!
              storage.model = model
            end
            
            if api.auth?
              auth = api.auth
        
              # Open => open data => GET, HEAD are excepted from Authorization 
              except = api.open? ? lambda {|request| ["GET", "HEAD"].include? request.request_method } : false
              authorizer = Npolar::Auth::Factory.instance("Couch", "api_user")

        
              use Npolar::Rack::Authorizer, { :auth => authorizer,
                :system => auth.system,
                :except? => except
              }
            end

            if api.middleware? and api.middleware.is_a? Array
              raise "@todo Not implemented"
            end

            if api.search? and api.search.engine?
        
              use Views::Api::Index
                # @todo Support config here {:svc => config.search }
        
              if "Solr" == api.search.engine
                #log.info "Solrizer #{api.path} #{api.search.core}"
                use Npolar::Rack::Solrizer, {
                  :core => api.search.core,
                  :force => api.search.force,
                  :path => api.path,
                  :facets => api.search.facets
                }
              elsif "Elastic" == api.search.engine
                raise "@todo Not implemented"
              end
  
            end

            before = []
            after = []
            
            if api.before?
              raise "Not implemented"
            else
              before << Npolar::Api::Json.before_lambda
            end
            if api.after?
              raise "Not implemented"
            else
              after << Npolar::Api::Json.after_lambda
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