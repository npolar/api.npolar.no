# encoding: utf-8
# This config.ru is the *production* configuration for api.npolar.no

# Set internal and external encoding for the application
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Initialize environment
ENV['GCMD_HTTP_USERNAME'] = ""
ENV['GCMD_HTTP_PASSWORD'] = ""
ENV['NPOLAR_API_COUCHDB'] = ""
ENV['NPOLAR_API_SOLR'] = ""
ENV['NPOLAR_API_ELASTICSEARCH'] = ""

LDAP_CONF = {
  :host => "",
  :port => 389,
  :base => "",
  :auth => { :username => "", :password => "", :method => :simple }
}

require "./load"

Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"]
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"]

# Middleware for *all* requests - use with caution
# a. Security
# use Rack::Throttle::Hourly,   :max => 1200 # requests
# use Rack::Throttle::Interval, :min => 110.1 # seconds
# use Npolar::Rack::SecureEdits (force TLS/SSL ie. https)

# b. Features
use Rack::JSONP
use Rack::Static, :urls => ["/css", "/img", "/xsl", "/favicon.ico", "/robots.txt"], :root => "public"
# use Npolar::Rack::Editlog, Npolar::Storage::Solr.new("/api/editlog"), except => ["/path"]
# use Npolar::Rack::Editlog, Npolar::Storage::Couch.new("/api/editlog"), except => ["/path"]

# http(s)://api.npolar.no/
# 
# Please keep all map statements below in alphabetical order

# Base Path
map "/" do

  #use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
  #  :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :facets => ['workspace', 'collection', 'topic', 'content', 'state']
  }
  
  run lambda{|env| [200,{"Content-Type" => "application/json"},[{"endpoints" => [
    "ctd", "dataset", "gps", "org", "person", "project", "publication", "radiation", "schema", "sensor", "service", "telemetry", "webcam"]}.to_json]]}
  
end

########################################################
################   WORKSPACE: /ctd   ###################
########################################################

map "/ctd" do
  
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::AttachmentDownloader, {:database => "ctd"}
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :facets => ['cruise'],
    :date_facets => {
      :field => 'created',
      :format => [:year]
    },
    :filter => ["workspace:ctd"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("ctd"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
  
end

########################################################
###############   WORKSPACE: /dataset   ################
########################################################

map "/dataset" do
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
  :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :facets => [:topic, :investigators, :area],
    :date_facets => {
      :field => 'created',
      :format => [:year]
    },
    :filter => ["workspace:metadata","collection:dataset"]
  }
  
  use Metadata::Rack::DifJsonizer
  use Npolar::Rack::JsonCleaner
  use Npolar::Rack::JsonValidator, {:schema => ["schema/datasetArray.json", "schema/dataset.json", "schema/minimalDataset.json"]}
  use Npolar::Rack::ChangeLogger, {:data_storage => Npolar::Storage::Couch.new("dataset"), :diff_storage => Npolar::Storage::Couch.new("dataset_revision")}
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("dataset"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
end

map "/dataset/revision" do
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api"}
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("dataset_revision"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
end

########################################################
#################   WORKSPACE: /gps   ##################
########################################################
  
map "/gps/profile" do

  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
  :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }

  use Npolar::Rack::JsonValidator, {:schema => ["schema/gpsArray.json", "schema/gps.json"]}
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :facets => ['sensor_name', 'grid', 'topic', 'state'],
    :date_facets => {
      :field => 'created',
      :format => [:year]
    },
    :filter => ["workspace:gps","collection:profile"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("gps_profile"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )

end

########################################################
#################   WORKSPACE: /org   ##################
########################################################

map "/org" do
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :filter => ["workspace:org"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("org"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
end

########################################################
###############   WORKSPACE: /person   #################
########################################################

map "/person" do
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :facets => [:org],
    :filter => ["workspace:person"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("person"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
end

########################################################
###############   WORKSPACE: /project   ################
########################################################

map "/project" do

  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :facets => [:author],
    :filter => ["workspace:project"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("project"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )

end

########################################################
##############   WORKSPACE: /publication   #############
########################################################

map "/publication" do
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::AttachmentDownloader, {:database => "publication"}
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :facets => [:author],
    :filter => ["workspace:publication"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("publication"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
end

########################################################
##############   WORKSPACE: /radiation   ###############
########################################################

map "/radiation" do
  
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :facets => [:placename, :area],
    :date_facets => {
      :field => 'created',
      :format => [:month, :year]
    },
    :filter => ["workspace:radiation"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("radiation"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
  
end

# Specific import pipe for the radiation station on zeppelinfjellet. Dumps into the
# global radiation database.

map "/radiation/zeppelin" do
  
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :facets => [:placename, :area],
    :date_facets => {
      :field => 'created',
      :format => [:month, :year]
    },
    :filter => ["workspace:radiation","placename:zeppelinfjellet"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("radiation"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
  
end
  
########################################################
################   WORKSPACE: /schema   ################
########################################################
  
map "/schema" do
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("schema"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
end

########################################################
################   WORKSPACE: /sensor   ################
########################################################

map "/sensor" do
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::AttachmentDownloader, {:database => "sensors"}
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :filter => ["workspace:sensor"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("sensor"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
  
end

########################################################
###############   WORKSPACE: /service   ################
########################################################

map "/service" do
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :filter => ["workspace:service"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("service"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
  
end

########################################################
#############   WORKSPACE: /telemetry   ################
########################################################

map "/telemetry" do
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
  :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
    use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :filter => ["workspace:telemetry"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("telemetry"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
end

########################################################
###############   WORKSPACE: /webcam   #################
########################################################

map "/webcam" do
  
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  use Npolar::Rack::AttachmentDownloader, {:database => "webcam"}
  use Npolar::Rack::Icelastic, {
    :searcher => ENV['NPOLAR_API_ELASTICSEARCH'],
    :facets => [:placename, :area],
    :date_facets => {
      :field => 'created',
      :format => [:month, :year]
    },
    :filter => ["workspace:webcam"]
  }
  
  run Npolar::Api::Core.new(nil,
    {
      :storage => Npolar::Storage::Couch.new("webcam"),
      :formats => ['json'],
      :accepts => ['json']
    }
  )
  
end