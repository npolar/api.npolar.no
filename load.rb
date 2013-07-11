require "bundler/setup"
require "yajl/json_gem" # https://github.com/brianmario/yajl-ruby
require "logger"
require "gcmd"

require "rack/throttle"
require "rack/contrib/jsonp"
require "rack/contrib/accept_format"
require "rack/ssl"
require "rack/commonlogger"
#require "rack/cache"
#require "rack/protection"


require_relative "./lib/npolar"
require_relative "./lib/npolar/exception"
require_relative "./lib/npolar/validation"

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
  puts file
  require_relative file
end

Dir.glob("./lib/*.rb").each do | file |
  require_relative file
end

require_relative "./lib/metadata/dataset"
require_relative "./lib/metadata/rack/dif_jsonizer"
Dir.glob("./lib/*/*.rb").each do | file |
  require_relative file
end
