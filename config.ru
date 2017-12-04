# encoding: utf-8
# config.ru for api.npolar.no

# Service API
# Use /service to create new API endpoints.
# Example: $ curl -niXPUT https://api.npolar.no/service/dataset-api -H "Content-Type: application/json" -d@seed/service/dataset-api.json
# Details: https://github.com/npolar/api.npolar.no/wiki/New-API
#
# Document API
# How to POST, PUT, DELETE, and GET documents
# * https://github.com/npolar/api.npolar.no/wiki/Example

# Validation
# For validation on all writes (POST, PUT), setup a "model" in the service document
# See https://github.com/npolar/api.npolar.no/wiki/Validation

# User API
# /user provides a lightweight alternative to LDAP or other directory services

# More topics
# * https://github.com/npolar/api.npolar.no/blob/master/README.md for more topics

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

#require "openssl"
#configfile = File.dirname(__FILE__)+"/config/config.rb"
#if File.exists? configfile
#  require configfile
#end
if not ENV.key? "NPOLAR_API_COUCHDB"
  raise "Please set environmental variable NPOLAR_API_COUCHDB to https://user:password@example.com:port"
end

require "./load"

Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"] # http://user:password@localhost:5984
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"] # http://localhost:8983/solr/
if ENV.key? "NPOLAR_API_LDAP"
  Npolar::Auth::Ldap.config = ENV["NPOLAR_API_LDAP"] # ldap://cn=manager,dc=example,dc=com:password@ldap.example.com?dc=example,dc=com
end
Metadata::Dataset.formats = ["json", "atom", "dif", "iso", "xml"]


bootstrap = Npolar::Api::Bootstrap.new
bootstrap.log = log = Npolar::Api.log
Npolar::Api.base = ENV["NPOLAR_API"]
log.info "Booting API #{Npolar::Api.base}
\tNPOLAR_API_COUCHDB\t\t#{URI.parse(ENV["NPOLAR_API_COUCHDB"]).host}
\tNPOLAR_API_ELASTICSEARCH\t#{ENV['NPOLAR_API_ELASTICSEARCH']}
\tNPOLAR_API_SOLR\t\t\t#{ENV['NPOLAR_API_SOLR']}"


# Middleware for *all* requests - use with caution
# use Rack::Throttle::Hourly,   :max => 3600000 # 3.6M requests per hour
# use Rack::Throttle::Interval, :min => 0.001 # 1/1000 seconds interval
# use Npolar::Rack::SecureEdits (force TLS/SSL ie. https)

# CORS
# https://github.com/cyu/rack-cors
use Rack::Cors do
  allow do
    # Allow read-write to localhost
    origins /http(s)?\:\/\/(localhost|10\.0\.2\.2)(:\d+)?/
    resource "*", :headers => :any, :methods => [:delete, :get, :head, :options, :post, :put], credentials: true
  end
  allow do
    # HTTPS: Allow read-write from any npolar.no host
    origins /^https\:\/\/(.+)?npolar\.no/
    resource "*", :headers => :any, :methods => [:delete, :get, :head, :options, :post, :put], credentials: true
  end
    allow do
    # Allow GET | HEAD | OPTIONS from any origin 
    origins "*"
    resource "*", :headers => :any, :methods => [:get, :head, :options], credentials: false
  end
end

use ::Rack::JSONP

use Rack::TryStatic, {urls: ["/css", "/js", "/img", "/xsl", "/schema", "code", "/favicon.ico", "/robots.txt"],
  root: "public",  :try => [".json", "/.json", 'index.html', '/index.html'] }

# Autorun all APIs in the /service database
# The service database is defined in /service/service-api.json
# APIs are started if they contain a "run" key holding the class name of a Rack
# application (like "Npolar::Api::Json") and a "schema" key holding
# "http://api.npolar.no/schema/api".
begin
  autorun_list = bootstrap.apis.select {|api| api.run? and api.run != "" }
rescue
  raise "Empty or nonexisting Service API database, please run ./bin/npolar-api-setup"
end

autorun_list.each do |api|

  map api.path do

    log.info "#{api.path} = #{api.run} [autorun] open data: #{api.open}"

    # Middleware for all autorunning APIs can be defined here
    # api.middleware = api.middleware? ? api.middleware : []
    # api.middleware << ["Npolar::Rack::RequireParam", { :params => "key", :except => lambda { |request| ["GET", "HEAD"].include? request.request_method }} ]

    # Editlog (enabled unless expliclitly disabled)
    editlog = (api.key?("editlog") and api.editlog.disabled == true) ? false : true

    if true == editlog

      max_body_size = case api.open
      when true
        (api.key?("editlog") and api.editlog.key?("max_body_size")) ? api.editlog.max_body_size : 255
      else
        0
      end

      use Npolar::Rack::EditLog,
        save: EditLog.save_lambda(uri: ENV["NPOLAR_API_COUCHDB"], database: Service.factory("editlog-api").database),
        index: EditLog.index_lambda(host: ENV["NPOLAR_API_ELASTICSEARCH"], log: false),
        open: api.open,
        max_body_size: max_body_size
    end

    if api.auth?
      log.info Npolar::Rack::Authorizer.authorize_text(api)
    end

    # Configuration for individual APIs
    config = api.config
    run Npolar::Factory.constantize(api.run).new(api, config)

  end
end

# OAI-PMH repository for datasets (as DIF XML)
#
# Supports all 6 verbs from v2 spec http://www.openarchives.org/OAI/openarchivesprotocol.html#ProtocolMessages
# * /dataset/oai?verb=Identify
# * /dataset/oai?verb=ListIdentifiers
# * /dataset/oai?verb=ListMetadataFormats
# * /dataset/oai?verb=ListSets
# * /dataset/oai?verb=GetRecord&metadataPrefix=dif&identifier=0323b588-5023-57d1-bf98-201cd8192730
# * /dataset/oai?verb=ListRecords&metadataPrefix=dif
#
# Time range
# * /dataset/oai?verb=ListIdentifiers&from=2013-11-01&until=2013-11-15&metadataPrefix=dif
# Sets (and time range)
# * /dataset/oai?verb=ListIdentifiers&from=2013-11-01&until=2014-01-01&metadataPrefix=dif&set=cryoclim.net
map "/dataset/oai" do
  provider = Metadata::OaiDatasetProvider.new
  run Npolar::Rack::OaiSkeleton.new(Views::Api::Index.new, :provider => provider)
end

map "/gcmd/concept/demo" do
  run Gcmd::Concept.new
end

# GeoJSON proxy ArcGIS REST server
map "/geodata" do
  run Npolar::Rack::ArcGISGeoJSON.new(nil, {base: "http://geodata.npolar.no/arcgis/rest/services"})
end
