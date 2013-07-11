# encoding: utf-8
# Configuration for http://api.npolar.no

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
require "./load"

log = Npolar::Api.log

Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"]
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"]

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


# Bootstrap /service and /user APIs
bootstrap = Npolar::Api::Bootstrap.new
bootstrap.log = log
bootstrap.bootstrap("service-api.json")
bootstrap.bootstrap("user-api.json")
# An effect of bootstrapping is that it's safe/impossible to DELETE these APIs
#bootstrap.bootstrap("schema-api.json")map "/my" do

## Get all services
service = Service.factory("service-api.json")
client = Npolar::Api::Client.new(Npolar::Storage::Couch.uri+"/#{service.database}")

services = client.get_body("_all_docs", {"include_docs"=>true}).rows.map {|row|

  Service.new(row.doc)

}


# JSON view
search = { :search => services.select {|api| "production" == api.lifecycle and api.open and "http://data.npolar.no/schema/api" == api.schema }.map {|api|
  { :href => api.path+"?q=", :title => api.path}
}}
config = { :svc => search }
# Autorun APIs
services.select { |api| ("http://data.npolar.no/schema/api" == api.schema)}.each do |api|
  if api.run =~ /(Npolar::Api::)?Json$/
    map api.path do
      log.info "#{api.path} API autorunning with Npolar::Api::Json and #{api.storage} database \"#{api.database}\""
      if api.auth?
        auth_methods = api.open? ? ["POST", "PUT", "DELETE"] : api.verbs
        log.info "#{api.path} authorize #{auth_methods.join(", ")} to '#{api.auth.authorize}' in system '#{api.auth.system}' using #{api.auth.authorizer}"
      end
       # merge in middleware from config files!
      run Npolar::Api::Json.new(api, config)
    end
  elsif api.search?
    map api.path do
      log.info "#{api.path} API autorunning with Npolar::Api::Search"
      config = {} # merge in middleware from config files!
      run Npolar::Api::Search.new(api, config)
    end
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
  map "/oai" do
    provider = Metadata::OaiRepository.new
    run Npolar::Rack::OaiSkeleton.new(Views::Api::Index.new, :provider => provider)
  end
end

map "/gcmd" do
  run Gcmd::Concept.new
end