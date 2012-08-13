require "spec_helper"
require "npolar/rack/request"
require "npolar/rack/response"
require "npolar/rack/middleware"
require "npolar/rack/authorizer"
require "yajl/json_gem"

describe Npolar::Rack::Authorizer do

  def testapp
    lambda { |env| [200, {}, [] ]}
  end

  def auth
    auth = double("Npolar::Rack::Authorizer::Backend")
    auth.stub(:roles => [])
    auth.stub(:match? => false)
    auth
  end

  def config=config=Npolar::Rack::Authorizer::CONFIG
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
    Npolar::Rack::Authorizer.new(testapp, config)
  end

  context "NOT authenticated" do
    it "401 Unauthorized" do
      get("/")
      last_response.status.should == 401
    end
  end

  context "authenticated" do

    before do
      config[:authenticated?] = lambda {| auth, request | true }
      # config[:auth].stub(:match? => true)
    end

    context "no roles" do
      ["GET", "HEAD", "DELETE", "POST", "PUT"].each do |method|
        it "#{method} 403 Forbidden" do
        config[:auth].stub(:roles => [])     
        request "/", :method => method
        last_response.status.should == 403
        end
      end
    end

    context "unknown roles" do
      ["GET", "HEAD", "DELETE", "POST", "PUT"].each do |method|
        it "#{method} 403 Forbidden" do
        config[:auth].stub(:roles => ["foo", "bar"])     
        request "/", :method => method
        last_response.status.should == 403
        end
      end
    end

    context "editor, sysadmin" do
      ["GET", "HEAD", "DELETE", "POST", "PUT"].each do |method|
        it "#{method} 200 OK" do
        config[:auth].stub(:roles => ["editor", "sysadmin"])     
        request "/", :method => method
        last_response.status.should == 200
        end
      end
    end

    context "reader" do
      ["GET", "HEAD"].each do |method|
        it "#{method} 200 OK" do
        config[:auth].stub(:roles => ["reader"])     
        request "/", :method => method
        last_response.status.should == 200
        end
      end

      ["DELETE", "POST", "PUT"].each do |method|
        it "#{method} 403 Forbidden" do
        config[:auth].stub(:roles => ["reader"])     
        request "/", :method => method
        last_response.status.should == 403
        end
      end
    end

  end

end
