# Test environment
ENV['RACK_ENV'] = 'test'

require "simplecov"

SimpleCov.start do
  add_filter do |src|
    src.lines.count < 5
  end
  add_filter "/load.rb"
  add_filter "/rackup/"
  add_filter "/spec/"
  add_group "Api", "lib/npolar/api"
  add_group "Storage", "lib/npolar/storage"
  add_group "Rack", "lib/npolar/rack"
  add_group "Model" do | src |
    src.filename =~ /lib\/(seaice|metadata)(.*)\.rb$/
  end
  add_group "Views", "views"
  end

require "bundler/setup"
require "rspec"
require "rack/test"
require "./load"


RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end
