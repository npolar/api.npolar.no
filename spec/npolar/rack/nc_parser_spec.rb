require "spec_helper"
require "numru/netcdf"
require "npolar/rack/nc_parser"

include NumRu

describe Npolar::Rack::NcParser do
  
  before(:each) do
    @data = File.open("spec/data/test.nc").read
    
    @env = Rack::MockRequest.env_for(
      "/test.nc",
      "REQUEST_METHOD" => "PUT",
      "rack.input" => StringIO.new(@data)
    )
  end
  
  subject do
    app = mock( "netcdf post", :call => Npolar::Rack::Response.new(
      StringIO.new(@data), 200, {"Content-Type" => "application/netcdf"} ) )
    
    # Stub the call method and have it return the calling argument.
    # This allows us to see in the request that is passed on to the
    # next layer in the middleware stack.
    app.stub!( :call ) do | arg |
      arg
    end
    
    Npolar::Rack::NcParser.new(app)    
  end
  
  context "#condition?" do
    
    it "should be true when PUT requests with format .nc" do
      subject.condition?(Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    it "should be true when POST request with format .nc" do
      @env["REQUEST_METHOD"] = "POST"
      subject.condition?(Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    it "should be true when PUT requests with content-type: application/netcdf" do
      @env = Rack::MockRequest.env_for("/", "REQUEST_METHOD" => "PUT", "CONTENT_TYPE" => "application/netcdf")
      subject.condition?(Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    it "should be true when POST requests with content-type: application/netcdf" do
      @env = Rack::MockRequest.env_for("/", "REQUEST_METHOD" => "POST", "CONTENT_TYPE" => "application/netcdf")
      subject.condition?(Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    it "should be false when PUT without format and content-type" do
      @env = Rack::MockRequest.env_for("/", "REQUEST_METHOD" => "PUT")
      subject.condition?(Npolar::Rack::Request.new(@env)).should be(false)
    end
    
    it "should be false when POST without format and content-type" do
      @env = Rack::MockRequest.env_for("/", "REQUEST_METHOD" => "POST")
      subject.condition?(Npolar::Rack::Request.new(@env)).should be(false)
    end
    
  end
  
  context "#handle" do
    
    it "should set the headers to content-type: application/json" do      
      subject.handle(Npolar::Rack::Request.new(@env))["CONTENT_TYPE"].should == "application/json"
    end
    
  end
  
  context "#parse_netcdf" do
    
    it "should generate a hash from the netcdf file" do
      subject.parse_netcdf(@data).should be_a_kind_of( Hash )
    end
    
  end
  
  context "Protected Methods" do
    
    context "#netcdf?" do
      
      it "should be true if format .nc" do
        subject.send( :netcdf?, Npolar::Rack::Request.new(@env) ).should be(true)
      end
      
      it "should be true if content-type: application/netcdf" do
        @env["PATH_INFO"] = "/"
        @env["CONTENT_TYPE"] = "application/netcdf"
        subject.send( :netcdf?, Npolar::Rack::Request.new(@env) ).should be(true)
      end
      
      it "should be false when format not .nc and no content-type" do
        @env["PATH_INFO"] = "/"
        subject.send( :netcdf?, Npolar::Rack::Request.new(@env) ).should be(false)
      end
      
      it "should be false with no format and content-type other then application/netcdf" do
        @env["PATH_INFO"] = "/"
        @env["CONTENT_TYPE"] = "application/xml"
        subject.send( :netcdf?, Npolar::Rack::Request.new(@env) ).should be(false)
      end
      
    end
    
  end
  
end
