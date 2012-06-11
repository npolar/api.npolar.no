# config.ru
require "bundler/setup"

# Server
require "./lib/api/exception"
#require "./lib/api/rack"
require "./lib/api/rack/middleware"
require "./lib/api/server"

# Collections
require "./lib/api/collection"
require "./lib/metadata/dif_atom.rb"
require "./lib/metadata/dataset_collection"

# Storage
require "./lib/api/storage"
require "./lib/api/storage/couch"

# Middleware
require "./lib/api/rack/require_param"
#require "./lib/metadata/rack/gcmd_dif"
#require "./lib/metadata/rack/save_gcmd_dif"
require "rack/contrib/jsonp"


# Rack middleware
use Rack::ShowExceptions

# Force apikey param (except on GET, HEAD)
#use Api::Rack::RequireParam, :params => ["apikey"], :except => lambda { |request| ["GET", "HEAD"].include? request.request_method }
use Rack::ConditionalGet
use Rack::ETag
use Rack::Lint

use Rack::Static, :urls => ["/xsl"], :root => "public"

config = lambda {|filename| JSON.parse(IO.read(File.join(".", "config", filename))) }

map "/_api" do
  map "/user" do
    server = Api::Server.new
    storage = Api::Storage::Couch.new(config.call("_api_user.json")["storage_config"])
    collection = Api::Collection.new(storage)
    server.collection = collection
    run server
  end
end

map "/metadata/dataset" do

  server = Api::Server.new

  metadata_config = JSON.parse(IO.read(File.join(".", "config", "metadata.json")))
  storage = Api::Storage::Couch.new(metadata_config["/metadata/dataset"]["storage_config"])

  collection = Api::Metadata::DatasetCollection.new(storage)

  server.collection = collection

  map "/feed"
  map "/feed.atom" do

  end

  run server

end

# @todo Use Rack:Cascade to find by UUID/code
