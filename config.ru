# encoding: utf-8
# config.ru for http://api.npolar.no

# How to publish a new API?
# * https://github.com/npolar/api.npolar.no/wiki/New-API

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require "./load"
log = Npolar::Api.log

Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"] # http://user:password@localhost:5984
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"] # http://localhost:8983/solr/
Npolar::Auth::Ldap.config = File.expand_path("./config/ldap.json")

# Bootstrap /service and /user APIs 
# If not found, the bootstrapping will create databases and inject service
# descriptions. These 2 APIs are started by the regular autorun below
bootstrap = Npolar::Api::Bootstrap.new
bootstrap.log = log
bootstrap.bootstrap("service-api.json")
bootstrap.bootstrap("user-api.json")

# Middleware for *all* requests - use with caution
# a. Security
use Rack::Throttle::Hourly,   :max => 1200000 # requests
use Rack::Throttle::Interval, :min => 0.00166 # 1/600 seconds
# use Npolar::Rack::SecureEdits (force TLS/SSL ie. https)

# b. Features
use Rack::JSONP
use Rack::Static, :urls => ["/css", "/img", "/xsl", "schema", "/favicon.ico", "/robots.txt"], :root => "public"
# use Npolar::Rack::GeoJSON
# use Npolar::Rack::Editlog, Npolar::Storage::Solr.new("/api/editlog"), except => ["/path"]
# use Npolar::Rack::Editlog, Npolar::Storage::Couch.new("/api/editlog"), except => ["/path"]

# JSON view
search = { :search => bootstrap.services.select {|api| true == api.open and "http://data.npolar.no/schema/api" == api.schema }.map {|api|
  { :href => api.path+"?q=", :title => api.path}
}}
config = { :svc => search }


# Autorun all APIs in the /service database
bootstrap.apis.select {|api| api.run? and api.run != "" }.each do |api|

  if not api.valid?
    log.error "Invalid service description for API #{api.path}: #{api.errors.join("\n")}"
  end
  
  map api.path do
  
    log.info "#{api.path} autoruns #{api.run}"

    if api.auth?
      auth_methods = api.open? ? ["POST", "PUT", "DELETE"] : api.verbs
      log.info "#{api.path} authorize #{auth_methods.join(", ")} to '#{api.auth.authorize}' in system '#{api.auth.system}' using #{api.auth.authorizer or "Npolar::Auth::Couch"}"
    end
    run Npolar::Factory.constantize(api.run).new(api, api.config)

  end
end

# /dataset
#   Discovery level metadata about a dataset
#
# $ curl -inX POST https://api.npolar.no/dataset -d@/path/dataset.json -H "Content-Type: application/json"
map "/dataset" do
  # Not autorun, but we still use the service configuration
  dataset = Service.factory("dataset-api.json")
  Metadata::Dataset.formats = ["json", "atom", "dif", "iso", "xml"] # hmmm
  Metadata::Dataset.accepts = dataset.accepts.keys #["application/json", "application/xml"]
  model = Metadata::Dataset.new

  storage = Npolar::Storage::Couch.new(dataset.database)
  storage.model = model

  # Auth
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "metadata",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  # DIF XML (<-)-> JSON
  use Metadata::Rack::DifJsonizer

  # HTML
  use Views::Api::Index, {:svc => search}

  # Solr search (GET)
  # Solr save (POST, PUT)
  # Solr delete (DELETE)
  use Npolar::Rack::Solrizer, { :core => "api",
    :facets => Metadata::Dataset.facets,
    :force => {"workspace" => "metadata", "collection" => "dataset"},
    :path => "/dataset",
    :to_solr => lambda {|hash|
        model = Metadata::Dataset.new(hash)
        model.to_solr        
    }
  }

  run Npolar::Api::Core.new(nil,
    { :storage => storage,
      :formats => Metadata::Dataset.formats,
      :accepts => Metadata::Dataset.accepts
    }
  )

  # /dataset/oai
  #   OAI-PMH repository
  #   /dataset/oai?verb=ListIdentifiers
  #   /dataset/oai?verb=GetRecord&metadataPrefix=dif&identifier=
  #map "/oai" do
  #  provider = Metadata::OaiRepository.new
  #  run Npolar::Rack::OaiSkeleton.new(Views::Api::Index.new, :provider => provider)
  #end
end

map "/gcmd" do
  run Gcmd::Concept.new
end