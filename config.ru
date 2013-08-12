# encoding: utf-8
# config.ru for http://api.npolar.no

# Service API
# Use /service to create new API endpoints.
# $ curl -niXPUT https://api.npolar.no/service/dataset-api -H "Content-Type: application/json" -d@seed/service/dataset-api.json
# Details: https://github.com/npolar/api.npolar.no/wiki/New-API

# Schema API
# Use /schema to publish JSON or other schemas for your document APIs.
# $ curl -niXPUT https://api.npolar.no/schema/dataset -H "Content-Type: application/json" -d@schema/dataset.json

# Document API
# How to POST, PUT, DELETE, and GET documents
# * https://github.com/npolar/api.npolar.no/wiki/Basics
# * https://github.com/npolar/api.npolar.no/wiki/Example

# Validation
# For validation on all writes (POST, PUT), setup a "model" in the service document
# See https://github.com/npolar/api.npolar.no/wiki/Validation

# User API
# /user

# https://github.com/npolar/api.npolar.no/blob/master/README.md for more topics

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
require "./load"
Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"] # http://user:password@localhost:5984
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"] # http://localhost:8983/solr/
Npolar::Auth::Ldap.config = File.expand_path("./config/ldap.json")
Metadata::Dataset.formats = ["json", "atom", "dif", "iso", "xml"]
  
# Bootstrap /service database and /user database
# /service is the API catalog
# /user is for authenticating and authorizing users
bootstrap = Npolar::Api::Bootstrap.new
bootstrap.log = log = Npolar::Api.log
bootstrap.bootstrap("service-api.json")
bootstrap.bootstrap("user-api.json")

# Middleware for *all* requests - use with caution
use Rack::Throttle::Hourly,   :max => 1200000 # 1.2M requests
use Rack::Throttle::Interval, :min => 0.00166 # 1/600 seconds
# use Npolar::Rack::SecureEdits (force TLS/SSL ie. https)
use Rack::Static, :urls => ["/css", "/img", "/xsl", "schema", "code", "/favicon.ico", "/robots.txt"], :root => "public"
# use Npolar::Rack::GeoJSON
# use Npolar::Rack::Editlog, Npolar::Storage::Solr.new("/api/editlog"), except => ["/path"]
# use Npolar::Rack::Editlog, Npolar::Storage::Couch.new("/api/editlog"), except => ["/path"]

# Autorun all APIs in the /service database
# The service database is defined in /service/service-api.json
# APIs are started if they contain a "run" key holding the class name of a Rack
# application (like "Npolar::Api::Json") and a "schema" key holding
# "http://api.npolar.no/schema/api".
bootstrap.apis.select {|api| api.run? and api.run != "" }.each do |api|

  map api.path do
  
    log.info "#{api.path} = #{api.run} [autorun]"
    
    # Middleware to all autorun API can be defined here   
    # api.middleware = api.middleware? ? api.middleware : []
    # api.middleware << ["Npolar::Rack::RequireParam", { :params => "key", :except => lambda { |request| ["GET", "HEAD"].include? request.request_method }} ]
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

map "/metadata/dataset" do
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(Npolar::Auth::Ldap.config), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  use Metadata::Rack::DifJsonizer
  run Npolar::Api::Core.new(nil, { :storage => Npolar::Storage::Couch.new("dataset"), :formats=>Metadata::Dataset.formats }) 
end