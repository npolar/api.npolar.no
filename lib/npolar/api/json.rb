require "hashie/mash"
require "rack/builder"

module Npolar
  module Api
    
    # JSON lego: A complete kit for running JSON APIs
    class Json

      def middleware
        @middleware ||= []
      end

      def middleware=middleware
        @middleware = middleware
      end

      def initialize(api, config={})

        @config = Hashie::Mash.new(config)
        @app = ::Rack::Builder.new do
          map "/" do

            to_solr = lambda {|hash|hash}
            if api.model?
              model = Npolar::Factory.constantize(api.model).new
              # This will trigger NameError if model is undefined
              to_solr = lambda {|hash|
                m = model.class.new(hash)
                m.to_solr # respond to ?        
            }
            else
              model = nil
            end
            
            if api.storage?

              if api.storage =~ /Couch(DB)?/i
                storage, database = api.storage, api.database
                storage = Npolar::Storage::Couch.new(database)
                storage.model = model

              else
                raise "Unsupported database: #{api.storage}"
              end
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
              api.middleware.each do |classname, config|
                c = {}
                if config.respond_to?(:each)
                  config.each do |k,v|
                    c[k.to_sym]=v
                  end
                end
                use Npolar::Factory.constantize(classname), c
              end
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
                

                use Npolar::Rack::Solrizer, {
                  :core => api.search.core,
                  :force => api.search.force,
                  :path => api.path,
                  :facets => api.search.facets,
                  :to_solr => to_solr
                }
              elsif /Elasticsearch/i =~ api.search.engine

                use Npolar::Rack::Icelastic, {
                  :uri => api.search.uri,
                  :index => api.search["index"],
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
              :formats => api.formats.keys,
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
              request.body.rewind
              if body !~ /^\s*\{.*\}\s*$/                
                return request
              end
               
              begin

                d = Hashie::Mash.new(JSON.parse body)                
                d.updated = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ") #DateTime.now.xmlschema
                
                unless d.published?
                  d.published = d.updated
                end
                unless d.author?
                  d.publisher = request.username
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
