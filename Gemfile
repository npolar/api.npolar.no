source "https://rubygems.org"

# Npolar gems

gem "nori"
gem "gcmd", git: "git://github.com/npolar/gcmd.git"
#gem "gcmd", path:  "../gcmd"

gem "icelastic", git: "git://github.com/npolar/icelastic.git"
#gem "npolar-rack-throttle", git: "git://github.com/npolar/rack-throttle.git" #, path:  "../rack-throttle"

gem "npolar-api-client-ruby", git: "git://github.com/npolar/npolar-api-client-ruby" #, path:  "../npolar-api-client-ruby"
#gem "npolar-api-client-ruby", path:  "../npolar-api-client-ruby"
 
gem "argos-ruby"#, path:  "../argos-ruby"
gem "highline" # for ./bin/npolar-api-setup


# HTTP/network
gem "unicorn"
gem "net-ldap"
gem "faraday"
#gem "faraday_middleware"
#gem "faraday", git: "git://github.com/lostisland/faraday"
gem "faraday_middleware", git: "git://github.com/lostisland/faraday_middleware"
gem "typhoeus", git: "git://github.com/typhoeus/typhoeus.git"
gem "eventmachine"
gem "em-http-request"

gem "chronic" # for oai
gem "oai"
#gem "oai", path:  "../ruby-oai"


# Rack
gem "rack" #, git: "git://github.com/rack/rack.git"
gem "rack-contrib" #, git: "git://github.com/rack/rack-contrib.git"
gem "rack-protection"
gem "rack-client" #https://github.com/halorgium/rack-client
gem "rack-ssl" #https://github.com/josh/rack-ssl
gem "rack-cache"
gem "rack-cors" #https://github.com/cyu/rack-cors

# Helpers
gem "yajl-ruby"
gem "ratom"
gem "nokogiri", "1.5.11"
gem "uuidtools"
gem "hashie", git: "git://github.com/intridea/hashie.git"
gem "json-schema", git: "git://github.com/hoxworth/json-schema.git"
gem "jsonify"

#gem "ruby-netcdf"
gem "addressable"
gem "mustache"

gem "libxml-ruby" #,git:  "git://github.com/xml4r/libxml-ruby.git"

# Search
# gem "rsolr" branch json_update
# Until branch "json_update" is merged...
gem "rsolr", git: "git://github.com/mootpointer/rsolr.git", :branch => "json_update"
#gem "rsolr" #, git:  "git://github.com/rsolr/rsolr.git"
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
 

