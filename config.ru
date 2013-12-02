# encoding: utf-8
# config.ru for http://api.npolar.no

# Service API
# Use /service to create new API endpoints.
# Example: $ curl -niXPUT https://api.npolar.no/service/dataset-api -H "Content-Type: application/json" -d@seed/service/dataset-api.json
# Details: https://github.com/npolar/api.npolar.no/wiki/New-API

# Schema API
# Use /schema to publish JSON or other schemas for your document APIs.
# Example: $ curl -niXPUT https://api.npolar.no/schema/dataset -H "Content-Type: application/json" -d@schema/dataset.json

# Document API
# How to POST, PUT, DELETE, and GET documents
# * https://github.com/npolar/api.npolar.no/wiki/Basics
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

#require 'raindrops'
#$stats ||= Raindrops::Middleware::Stats.new
#use Raindrops::Middleware, :stats => $stats

require "./load"
if File.exists? "./config/config.rb"
  require "./config/config.rb"
end
Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"] # http://user:password@localhost:5984
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"] # http://localhost:8983/solr/
Npolar::Auth::Ldap.config = File.expand_path("./config/ldap.json")
Metadata::Dataset.formats = ["json", "atom", "dif", "iso", "xml"]
  
# Bootstrap (create if needed) /service database and /user database
# /service is the API catalog
# /user is for authenticating and authorizing users
bootstrap = Npolar::Api::Bootstrap.new
bootstrap.log = log = Npolar::Api.log

log.info "Booting API #{Npolar::Api.base}
\tNPOLAR_API_COUCHDB\t\t#{URI.parse(ENV["NPOLAR_API_COUCHDB"]).host}
\tNPOLAR_API_ELASTICSEARCH\t#{ENV['NPOLAR_API_ELASTICSEARCH']}
\tNPOLAR_API_SOLR\t\t\t#{ENV['NPOLAR_API_SOLR']}"

bootstrap.bootstrap("service-api.json")
bootstrap.bootstrap("user-api.json")

# Middleware for *all* requests - use with caution
use Rack::Throttle::Hourly,   :max => 1200000 # 1.2M requests per hour
use Rack::Throttle::Interval, :min => 0.00166 # 1/600 seconds interval
# use Npolar::Rack::SecureEdits (force TLS/SSL ie. https)

use Rack::Static, :urls => ["/css", "/img", "/xsl", "schema", "code", "/favicon.ico", "/robots.txt"], :root => "public"
use ::Rack::JSONP
# use Npolar::Rack::GeoJSON


# Autorun all APIs in the /service database
# The service database is defined in /service/service-api.json
# APIs are started if they contain a "run" key holding the class name of a Rack
# application (like "Npolar::Api::Json") and a "schema" key holding
# "http://api.npolar.no/schema/api".
bootstrap.apis.select {|api| api.run? and api.run != "" }.each do |api|

  map api.path do
  
    log.info "#{api.path} = #{api.run} [autorun] open data: #{api.open}"

    # Middleware for all autorunning APIs can be defined here   
    # api.middleware = api.middleware? ? api.middleware : []
    # api.middleware << ["Npolar::Rack::RequireParam", { :params => "key", :except => lambda { |request| ["GET", "HEAD"].include? request.request_method }} ]
    editlog = (api.key?("editlog") and api.editlog.disabled == true) ? false : true
    if true == editlog
        use Npolar::Rack::EditLog,
      save: EditLog.save_lambda(
        uri: ENV["NPOLAR_API_COUCHDB"],
        database: "api_editlog"
      ),
      index: EditLog.index_lambda(host: ENV["NPOLAR_API_ELASTICSEARCH"], log: false),
      open: api.open
    end
    
    if api.auth?
      log.info Npolar::Rack::Authorizer.authorize_text(api)
    end

    # Configuration for individual APIs
    config = api.config
    run Npolar::Factory.constantize(api.run).new(api, config)

  end
end

# /dataset/oai = OAI-PMH repository
# https://github.com/code4lib/ruby-oai
# Identify, ListIdentifiers, ListRecords, GetRecords, ListSets, ListMetadataFormat
#   /dataset/oai?verb=ListSets
#   /dataset/oai?verb=ListIdentifiers
#   /dataset/oai?verb=GetRecord&metadataPrefix=dif&identifier=
#map "/oai" do
#  provider = Metadata::OaiRepository.new
#  run Npolar::Rack::OaiSkeleton.new(Views::Api::Index.new, :provider => provider)
#end

map "/gcmd/concept/demo" do
  run Gcmd::Concept.new
end