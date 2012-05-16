# config.ru

# Server
require "./lib/api/server"

# Collections
require "./lib/api/collection"
require "./lib/metadata/dataset_collection"


# Storage
require "./lib/api/storage"
require "./lib/api/storage/couch"

# Middleware
require "./lib/metadata/rack/gcmd_dif"
require "./lib/metadata/rack/save_gcmd_dif"
require "rack/contrib/jsonp"

# Rack middleware
use Rack::ShowExceptions
use Rack::JSONP
use Rack::ConditionalGet
use Rack::ETag
use Rack::Lint

use Rack::Static, :urls => ["/xsl"], :root => "public"

map "/metadata/dataset" do

  server = Api::Server.new

  metadata_config = JSON.parse(IO.read(File.join(".", "config", "metadata.json")))
  storage = Api::Storage::Couch.new(metadata_config["/metadata/dataset"]["storage_config"])

  collection = Api::Metadata::DatasetCollection.new(storage)

  server.collection = collection

  use Metadata::Rack::SaveGcmdDif
  #use Metadata::Rack::GcmdDif

  run server

end

# @todo Use Rack:Cascade to find by UUID/code
