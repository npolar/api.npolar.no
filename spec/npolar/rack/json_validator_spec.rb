require "spec_helper"
require "npolar/rack/middleware"
require "npolar/rack/json_validator"

describe Npolar::Rack::JsonValidator do

  before(:each) do
    @data = File.open( "spec/data/ctd-example.json" ).read
    @env = Rack::MockRequest.env_for(
      "/test.json",
      "REQUEST_METHOD" => "PUT",
      "rack.input" => StringIO.new(@data)
    )
  end

  subject do
    app = mock( "ctd import", :call => Npolar::Rack::Response.new(
      StringIO.new(@data), 200, {"Content-Type" => "application/json"} ) )    
    
    Npolar::Rack::JsonValidator.new(app, {:schema => "spec/data/CTD-schema.json"} )
  end
  
  context "#condition?" do
    
    it "should be true with method PUT and .json as format" do
      subject.condition?( Npolar::Rack::Request.new(@env) ).should be( true )
    end
    
    it "should be true with method POST and .json as format" do
      @env["REQUEST_METHOD"] = "POST"
      subject.condition?( Npolar::Rack::Request.new(@env) ).should be( true )
    end
    
    it "should be false when GET" do
      @env["REQUEST_METHOD"] = "GET"
      subject.condition?( Npolar::Rack::Request.new(@env) ).should be( false )
    end
    
  end
  
  context "#handle" do
    
    it "should pass on the request if valid" do
      subject.handle( Npolar::Rack::Request.new(@env) )
    end
    
    it "should return errors as json when invalid" do
      @env['rack.input'] = StringIO.new("\"metadata\":\"id\"")
      status, headers, body = subject.handle( Npolar::Rack::Request.new(@env) )
      status.should == 406
    end
    
  end
  
  context "schema validators" do
    
    context "#valid?" do    
    
      it "should return true when the data is schema valid" do
        subject.valid?( @data ).should be( true )
      end
      
      it "should return false whne the data is invalid" do
        subject.valid?( "" ).should be( false )
      end
    
    end
    
    context "#validate" do
      
      it "should return an empty array when valid" do
        subject.validate( @data ).should == []
      end
      
      it "should return an array with errors when invalid" do
        subject.validate( "" ).any?.should_not be( nil )
      end
      
    end
    
  end
  
  context "Protected methods" do
      
    context "#json?" do
      
      it "should be true when format .json" do        
        subject.send( :json?, Npolar::Rack::Request.new(@env) ).should be( true )
      end
      
      it "should be true when content-type json" do
        @env["CONTENT_TYPE"] = "application/json"
        subject.send( :json?, Npolar::Rack::Request.new(@env) ).should be( true )
      end
      
      it "should return false when the format isn't json" do
        @env["PATH_INFO"] = "/.nc"
        subject.send( :json?, Npolar::Rack::Request.new(@env) ).should be( false )
      end
      
      it "should return false when content-type isn't application/json" do
        @env["CONTENT_TYPE"] = "application/schema+json"
        subject.send( :json?, Npolar::Rack::Request.new(@env) ).should be( true )
      end
      
    end
    
  end

end