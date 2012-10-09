require "spec_helper"
require "npolar/rack/middleware"
require "npolar/rack/solrizer"
require "yajl/json_gem"

describe Npolar::Rack::Solrizer do

  def testapp
    lambda { |env| [200, {}, [] ]}
  end

  def config=config= Npolar::Rack::Solrizer::CONFIG
    @config = config
  end

  def config
    @config ||= Npolar::Rack::Authorizer::CONFIG.merge(
      :auth => auth,
      :system => "system1"
    )
  end

  def after
    @config = nil
  end

  def app
    Npolar::Rack::Solrizer.new(testapp, config)
  end

end