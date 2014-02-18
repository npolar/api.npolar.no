require "bundler/setup"
require "yajl/json_gem" # https://github.com/brianmario/yajl-ruby
require "logger"
require "gcmd"
require "rsolr"
require "npolar/api/client"
require "icelastic"

#require "rack/throttle"
require "rack/contrib/jsonp"
require "rack/contrib/accept_format"
require "rack/ssl"
require "rack/commonlogger"
#require "rack/cache"
#require "rack/protection"

require "typhoeus/adapters/faraday"

require_relative "./lib/npolar"
require_relative "./lib/npolar/exception"
require_relative "./lib/npolar/validation"
require_relative "./lib/npolar/api/"
#require_relative "./lib/npolar/api/command"
require_relative "./lib/npolar/api/solr_query"

require "mustache"
require "./views/views"
require "./lib/npolar/mustache"
require "./lib/npolar/mustache/json_view"


# This is messy, but effective

Dir.glob("./views/**/**/*.rb").each do | file |
  require_relative file
end

Dir.glob("./lib/npolar/*.rb").each do | file |
  require_relative file
end

Dir.glob("./lib/npolar/**/**/*.rb").each do | file |
  require_relative file
end

Dir.glob("./lib/*.rb").each do | file |
  require_relative file
end

require_relative "./lib/npolar/rack/middleware"
require_relative "./lib/npolar/rack/edit_log"

require_relative "./lib/metadata/dataset"
require "oai"

require_relative "./lib/metadata/oai_dumb_couchdb_model"
require_relative "./lib/metadata/oai_directory_interchange_format"
require_relative "./lib/metadata/rack/dif_jsonizer"
Dir.glob("./lib/*/*.rb").each do | file |
  require_relative file
end
