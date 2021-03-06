source "https://rubygems.org" do
    gem "nori", "2.6.0"
    gem "highline"

    # HTTP/network
    gem "unicorn"
    gem "net-ldap"
    gem "faraday"
    gem "faraday_middleware", "0.11.0.1"
    gem "typhoeus", "1.1.2"
    gem "eventmachine"
    gem "em-http-request"
    gem "chronic"
    gem "oai"

    # Rack
    gem "rack", "1.6.8"
    gem "rack-contrib", "1.4.0"
    gem "rack-protection"
    gem "rack-client" #https://github.com/halorgium/rack-client
    gem "rack-ssl" #https://github.com/josh/rack-ssl
    gem "rack-cache"
    gem "rack-cors" #https://github.com/cyu/rack-cors

    # Helpers
    gem "yajl-ruby", "1.3.1"
    gem "ratom"
    gem "nokogiri", "1.5.11"
    gem "uuidtools"
    gem "hashie", "3.4.6"
    gem "json-schema", "2.8.0"
    gem "jsonify"
    gem "require_all"

    #gem "ruby-netcdf"
    gem "addressable"
    gem "mustache"
    gem "libxml-ruby" #,git:  "https://github.com/xml4r/libxml-ruby.git"
end

## Npolar gems
gem "gcmd"                   , git: "https://github.com/npolar/gcmd.git"                   , branch: "master"
gem "icelastic"              , git: "https://github.com/npolar/icelastic.git"              , branch: "master"
gem "npolar-api-client-ruby" , git: "https://github.com/npolar/npolar-api-client-ruby.git" , branch: "master"
gem "argos-ruby"             , git: "https://github.com/npolar/argos-ruby"
gem "rack-gouncer"           , git: "https://github.com/npolar/rack-gouncer.git"

# Search
# gem "rsolr" branch json_update
# Until branch "json_update" is merged...
gem "rsolr", git: "https://github.com/mootpointer/rsolr.git", :branch => "json_update"
gem "elasticsearch", git: "https://github.com/elasticsearch/elasticsearch-ruby.git"

# Dev/Test
group :development, :test do
  gem "thin"
  gem "shotgun"
  gem "rspec"
  gem "rack-test"
  gem "simplecov"
  gem "ruby-prof"
end
