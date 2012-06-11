require 'simplecov'
SimpleCov.start do
  add_filter "/rackup/"
  add_filter "/spec/"
  add_group "Server", "lib/api/server"
  add_group "Collection", "lib/api/collection"
  add_group "Storage", "lib/api/storage"
  add_group "Rack", "lib/api/rack"
  

end

require "bundler/setup"
require "rspec"
require "rack/test"

# Test environment
ENV["RACK_ENV"] = "test"

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end