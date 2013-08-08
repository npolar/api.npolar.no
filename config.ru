# encoding: utf-8
# config.ru for http://api.npolar.no

# All APIs in the /service API database (CouchDB) are autorun by this
# config.ru file - provided  that the service description contains a "run" key
# holding the class name of a Rack application (like Npolar::Api::Json) and
# a "schema" key holding "http://api.npolar.no/schema/api".

# Example usage
# * https://github.com/npolar/api.npolar.no/wiki/Example

# How to publish a new API?
# $ curl -niXPUT https://api.npolar.no/service/dataset-api -H "Content-Type: application/json" -d@seed/service/dataset-api.json
# Details: https://github.com/npolar/api.npolar.no/wiki/New-API

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
require "./load"
Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"] # http://user:password@localhost:5984
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"] # http://localhost:8983/solr/
Npolar::Auth::Ldap.config = File.expand_path("./config/ldap.json")
Metadata::Dataset.formats = ["json", "atom", "dif", "iso", "xml"]
  
# Bootstrap /service database and /user database
# /service is the service catalog
# /user is used for authenticating and authorizing users
# Both of these are needed to publishing regular APIs.

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

# Autorun all APIs in the /service database.
# The service database is defined in /service/service-api.json
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