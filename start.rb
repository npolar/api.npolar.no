require "bundler/setup"
require "yajl/json_gem" # https://github.com/brianmario/yajl-ruby

# Server
require "./lib/npolar/exception"
require "./lib/npolar/rack/request"
require "./lib/npolar/rack/response"
require "./lib/npolar/rack/middleware"
require "./lib/npolar/api"
require "./lib/npolar/api/core"

# Auth
#require "./lib/npolar/auth"
require "./lib/npolar/auth/couch"
require "./lib/npolar/rack/authorizer"
require "./lib/npolar/auth/ldap"

# Storage
require "./lib/npolar/storage/couch"

# Middleware
require "./lib/npolar/rack/middleware"
require "./lib/npolar/rack/solrizer"
require "./lib/npolar/rack/require_param"
require "./lib/npolar/rack/validate_id"
require "./lib/npolar/rack/require_param"

require "rack/throttle"
require "rack/contrib/jsonp"
require "rack/contrib/accept_format"
require "rack/ssl"
require "rack/commonlogger"
require "rack/cache"

require "gcmd/http"
require "gcmd/concepts"




# Collections
require "./lib/metadata/dif_atom.rb"
require "./lib/metadata/rack/dif_jsonizer"

# Views
require "mustache"
require "./views/gcmd/index"
