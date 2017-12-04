# encoding: utf-8
require "hashie/mash"
require "rack/builder"
require "base64"

module Npolar
  module Api

    # JSON middleware lego: A complete kit for running JSON APIs
    class Json

      def middleware
        @middleware ||= []
      end

      def middleware=middlewareq
        @middleware = middleware
      end

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

              if api.storage =~ /Couch(DB)?/i
                storage, database = api.storage, api.database
                storage = Npolar::Storage::Couch.new(database)
                storage.model = model
              else
                raise "Unsupported database: #{api.storage}"
              end
            end

            # FIXME remce => select goeunder add except/bypass lambda/clasa
            #if api.auth?
            #  auth = api.auth
            #
            #  # Open => open data => GET, HEAD, OPTIONS are excepted from Authorization
            #  except = api.open? ? lambda {|request| ["GET", "HEAD", "OPTIONS"].include? request.request_method } : false
            #
            #  authorizer = case api.auth.authorizer
            #    when /Ldap/i then begin
            #      #Npolar::Auth::Ldap.config = ENV["NPOLAR_API_LDAP"]
            #      Npolar::Auth::Ldap.new(Npolar::Auth::Ldap.config)
            #    end
            #    else Npolar::Auth::Couch.new(Service.factory("user-api.json").database)
            #  end
            #
            #  use Npolar::Rack::Authorizer, { :auth => authorizer,
            #    :system => auth.system,
            #    :except? => except
            #  }
            #end



            if api.middleware? and api.middleware.is_a? Array

              api.middleware.each do |classname, config|

                if classname.is_a? Hash
                  config = classname.config || {}
                  classname = classname.fetch(:class)

                end

                c = {}
                if not config.nil? and config.respond_to?(:each)
                  config.each do |k,v|
                    c[k.to_sym]=v
                  end
                end
                use Npolar::Factory.constantize(classname), c
              end
            end

            if api.search? and api.search.engine?

              # List of APIs
              services = Service.services.map {|svc|
                { :href => (svc.search? and svc.search.engine != "") ? svc.path+"/?q=" : svc.path+"/_ids.json",
                  :text => svc.path,
                  :title => (svc.search? and svc.search.engine != "") ? "#{svc.title} [search]" : "#{svc.title} [identifiers]",
                }
              }
              use Views::Api::Index, { :services => services}



              if /Solr/i =~ api.search.engine

                use Npolar::Rack::Solrizer, {
                  :core => api.search.core,
                  :force => api.search.force,
                  :path => api.path,
                  :dates => api.search.dates||[],
                  :facets => api.search.facets||[],
                  :range_facets => api.search.range_facets||[],
                  :group =>  api.search.group||[],
                  :fl => api.search.fields||"*",
                  :geojson => api.geojson||{},
                  :to_solr => lambda {|hash|
                    if model.nil?
                      hash
                    else
                      m = model.class.new(hash)
                      m.to_solr.to_json
                    end
                  }
                }
              elsif /Elasticsearch/i =~ api.search.engine

                #use Npolar::Rack::HashCleaner

                # Relative URIs => depend on NPOLAR_API_ELASTICSEARCH
                if api.search.url.nil?
                  uri = URI.parse(ENV["NPOLAR_API_ELASTICSEARCH"]||"http://localhost:9200")
                else
                 uri = URI.parse(api.search.url)
                end


                use ::Rack::Icelastic, {
                  :url => uri,
                  :index => api.search["index"],
                  :type => api.search.type,
                  :log => api.search.log,
                  :params => api.search.params,
                  :geojson => api.geojson
                }

              end
            end

            if api.before? and api.before !~ /[.]/
              before = []
            else
              before = [Npolar::Api::Json.before_lambda]
            end

            after = [Npolar::Api::Json.after_lambda]

            if api.before? and api.before =~ /[.]/
              name, met = api.before.split(".")
              bef = Npolar::Factory.constantize(name)
              before << bef.send(met.to_sym)
            end

            if api.after?
              name, met = api.after.split(".")
              aft = Npolar::Factory.constantize(name)
              after << aft.send(met.to_sym)
            end

            accepts = api.accepts.nil? ? {} : api.accepts
            formats = api.formats.nil? ? {} : api.formats

            run Core.new(nil,
              {:storage => storage,
              :formats => formats.keys,
              :methods => api.verbs,
              :accepts => accepts.keys,
              :before => before,
              :after => after}
            )

          end
        end
      end

      def call(env)
        @app.call(env)
      end

      def self.jwt_payload(jwt)
        header, payload, crypto = jwt.split(".")
        payload += '=' * (4 - payload.length.modulo(4))
        Base64.decode64(payload.tr('-_', '+/'))
      end

      # Adds "created", "edited", "created_by", "edited_by" before POST/PUT
      # published?
      # published_by published_username
      def self.before_lambda
        lambda {|request|
          if ["POST", "PUT"].include? request.request_method and "application/json" == request.media_type
            begin

              documents = JSON.parse(request.body.read)
              documents = documents.is_a?(Hash) ? [documents] : documents
              documents = documents.map {|d|
                document = Hashie::Mash.new(d)

                document.updated = Time.now.utc.iso8601 #strftime("%Y-%m-%dT%H:%M:%SZ") #DateTime.now.xmlschema
                document.updated_by = URI.decode(request.username)

                unless document.created?
                  document.created = document.updated || document.edited
                end

                unless document.created_by?
                  document.created_by = document.updated_by || document.edited_by
                end
                document

              }
              body = case documents.size
                when 1
                  documents[0].to_json
                else
                  documents.to_json
              end
              request.body = body
              request

            rescue JSON::ParserError
              # Crap JSON, don't do anyting
              request
            end
          else
            request
          end
        }
      end

      def self.after_lambda
        lambda {|request, response|

          # Location header on POST, PUT, DELETE
          # @todo Absolute URI
          if request.write? and (200..299).include? response.status and "application/json" == request.media_type
            location = request.path.gsub(/\/+$/, "")
            rev = nil
            id = nil

            if not response.header["ETag"].nil?
              rev = response.header["ETag"]
              if rev =~ /["]/
                rev = rev.gsub(/["]/, "")
              end
            end

            begin
              d = JSON.parse(response.body.join)
              id = d["id"]
            rescue
              #
            end

            if request.post?
              if not id.nil?
                location += "/#{id}"
              end
            end

            if not rev.nil?
              location += "?rev=#{rev}"
            end
            response.header["Location"]=location
          end

          response
        }
      end
    end
  end
end
