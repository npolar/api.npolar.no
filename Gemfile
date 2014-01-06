source "https://rubygems.org"

# NP Gems
gem "gcmd", git: "git://github.com/npolar/gcmd.git"
gem "icelastic", git: "git://github.com/npolar/icelastic.git"
gem "npolar-rack-throttle", git: "git://github.com/npolar/rack-throttle.git" #, path:  "../rack-throttle"

# Network
gem "unicorn"
gem "net-ldap"
gem "faraday"
gem "faraday_middleware"

# Rack
gem "rack", git: "git://github.com/rack/rack.git"
gem "rack-contrib", git: "git://github.com/rack/rack-contrib.git"
gem "rack-protection"
gem "rack-client" #https://github.com/halorgium/rack-client
gem "rack-ssl" #https://github.com/josh/rack-ssl
gem "rack-cache"

# Helpers
gem "yajl-ruby"
gem "ratom"
gem "nokogiri"
gem "uuidtools"
gem "hashie", git: "git://github.com/intridea/hashie.git"
gem "json-schema", git: "git://github.com/hoxworth/json-schema.git"
gem "jsonify"
gem "oai"
gem "ruby-netcdf"
gem "addressable"
gem "mustache"

# Search
#gem "rsolr", git:  "git://github.com/mwmitchell/rsolr.git"
# Until branch "json_update" is merged...
gem "rsolr", git: "git://github.com/mootpointer/rsolr.git", :branch => "json_update"
gem "elasticsearch", git: "git://github.com/elasticsearch/elasticsearch-ruby.git"

# Dev/Test
group :development, :test do
  gem "thin"
  gem "shotgun"
  gem "rspec"
  gem "rack-test"
  gem "simplecov"
  gem "ruby-prof"
end
