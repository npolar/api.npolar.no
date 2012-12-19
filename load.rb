require "bundler/setup"
require "yajl/json_gem" # https://github.com/brianmario/yajl-ruby
require "logger"


#
#Dir.glob("./lib/npolar/**/*.rb").each do | file |
#  require file
#end

# Server
require "./lib/npolar/exception"
require "./lib/npolar/rack/request"
require "./lib/npolar/rack/response"
require "./lib/npolar/rack/middleware"
require "./lib/npolar/api"
require "./lib/npolar/api/core"

## Auth
require "./lib/npolar/auth/couch"
require "./lib/npolar/auth/ldap"
require "./lib/npolar/auth/exception"
require "./lib/npolar/rack/authorizer"

## Storage
require "./lib/npolar/storage/couch"

## Search/Solr
require "./lib/npolar/api/solr_query"
require "./lib/npolar/api/solr_feed_writer"

## Middleware
require "./lib/npolar/rack/middleware"
require "./lib/npolar/rack/atomizer"
require "./lib/npolar/rack/solrizer"
require "./lib/npolar/rack/require_param"
require "./lib/npolar/rack/validate_id"
require "./lib/npolar/rack/require_param"


require "rack/protection"
require "rack/throttle"
require "rack/contrib/jsonp"
require "rack/contrib/accept_format"
require "rack/ssl"
require "rack/commonlogger"
require "rack/cache"

require "gcmd"

require "./lib/biology"
require "./lib/biology/sighting"
require "./lib/polarbear"
require "./lib/polarbear/interaction"

# Metadata
require "./lib/metadata.rb"
require "./lib/metadata/dataset.rb"
require "./lib/metadata/dif_transformer.rb"
require "./lib/metadata/rack/dif_jsonizer"
require "./lib/metadata/oai"
require "./lib/metadata/oai_repository"
require "./lib/npolar/rack/oai_skeleton"

# Seaice
require "./lib/seaice.rb"
require "./lib/tracking.rb"
Dir.glob("./lib/tracking/*.rb").each do | file |
  require file
end


# Views
require "mustache"
require "./views/views"
require "./lib/npolar/mustache"
require "./lib/npolar/mustache/json_view"
require "./views/workspace"
require "./views/collection"

Dir.glob("./views/*/*.rb").each do | file |
  require file
end
