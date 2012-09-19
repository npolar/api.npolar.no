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
    auth.stub(:username=)

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

    it "Bad :authenticated? lambda" do 
      authorizer = Npolar::Rack::Authorizer.new(testapp, :authenticated? => Object.new)
      authorizer.authenticated?.should == false
    end

    it "Bad :authorized? lambda" do 
      authorizer = Npolar::Rack::Authorizer.new(testapp, :authorized? => Object.new)
      authorizer.authorized?.should == false
    end
  end

  context "authenticated" do

    before do
      config[:authenticated?] = lambda {| auth, request | true }
    end

    context "no roles" do
      ["GET", "HEAD", "DELETE", "POST", "PUT"].each do |method|
        it "#{method} => 403 Forbidden" do
        config[:auth].stub(:roles => [])     
        request "/", :method => method
        last_response.status.should == 403
        end
      end
    end

    context "unknown roles" do
      ["GET", "HEAD", "DELETE", "POST", "PUT"].each do |method|
        it "#{method} => 403 Forbidden" do
        config[:auth].stub(:roles => ["foo", "bar"])     
        request "/", :method => method
        last_response.status.should == 403
        end
      end
    end

    context "editor, sysadmin" do
      ["GET", "HEAD", "DELETE", "POST", "PUT"].each do |method|
        it "#{method} => 200 OK" do
        config[:auth].stub(:roles => ["editor", "sysadmin"])     
        request "/", :method => method
        last_response.status.should == 200
        end
      end
    end

    context "reader" do
      ["GET", "HEAD"].each do |method|
        it "#{method} => 200 OK" do
        config[:auth].stub(:roles => ["reader"])     
        request "/", :method => method
        last_response.status.should == 200
        end
      end

      ["DELETE", "POST", "PUT"].each do |method|
        it "#{method} => 403 Forbidden" do
        config[:auth].stub(:roles => ["reader"])     
        request "/", :method => method
        last_response.status.should == 403
        end
      end
    end

    context "Unsupported HTTP method [even if sysadmin]" do
      it "PATCH => 403 Forbidden" do
        config[:auth].stub(:roles => ["sysadmin"])     
        request "/", :method => "PATCH"
        last_response.status.should == 403
      end
    end

  end


  context "Exceptions" do
    context "#authenticated?" do
      it "Trap all Exceptions and return false" do
        authorizer = Npolar::Rack::Authorizer.new
        lambda { authorizer.authenticated? }.should_not raise_error
        authorizer.authenticated?.should == false
      end
    end

    context "#authorized?" do
      it "Trap all Exceptions and return false" do
        authorizer = Npolar::Rack::Authorizer.new
        lambda { authorizer.authorized? }.should_not raise_error
        authorizer.authorized?.should == false
      end
    end
  end

  context "Setters and getters" do
    it "auth" do 
      authorizer = Npolar::Rack::Authorizer.new(testapp, :authorized? => Object.new)
      authorizer.auth.should == nil
      auth = Object.new
      authorizer.auth=auth
      authorizer.auth.should be auth
    end

    it "system" do 
      authorizer = Npolar::Rack::Authorizer.new(testapp, :authorized? => Object.new)
      authorizer.system.should == nil
      system = Object.new
      authorizer.system=system
      authorizer.system.should be system
    end
  end

  context "#except?" do
    it "true => no auth" do
      config[:except?] = true
      request "/", :method => "GET"
      last_response.status.should == 200
    end
    it "lambda {|request| ... }" do
      config[:except?] = lambda {|request| "GET" == request.request_method}
      request "/", :method => "GET"
      last_response.status.should == 200
    end
  end

end