require "bundler/setup"

require "yajl/json_gem" # https://github.com/brianmario/yajl-ruby

# Server


require "./lib/npolar/exception"
require "./lib/npolar/rack/request"
require "./lib/npolar/rack/response"
require "./lib/npolar/rack/middleware"
require "./lib/npolar/api"
require "./lib/npolar/api/core"
#require "./lib/npolar/auth"
require "./lib/npolar/auth/couch"

require "./lib/npolar/rack/authorizer"
require "./lib/npolar/auth/ldap"

# Collections
require "./lib/metadata/dif_atom.rb"

# Storage
require "./lib/npolar/storage/couch"

# Middleware 
require "./lib/npolar/rack/require_param"
require "./lib/metadata/rack/dif"
require "./lib/npolar/rack/validate_id"

require "rack/throttle"
require "rack/contrib/jsonp"
require "rack/contrib/accept_format"
require "rack/ssl"
require "rack/commonlogger"

