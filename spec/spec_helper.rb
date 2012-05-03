require "rspec"
require "rack/test"

# Test environment
ENV["RACK_ENV"] = "test"

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end