require "spec_helper"
require "npolar/rack/json_cleaner"

describe Npolar::Rack::JsonCleaner do
  
  before(:each) do
    @env = Rack::MockRequest.env_for(
      "/test.json",
      "REQUEST_METHOD" => "PUT"
    )
  end
  
  subject do
    app = mock( "json cleaner", :call => "" )
    app.stub(:call) {|env| [200, {}, [env['rack.input'].read]]}
    
    Npolar::Rack::JsonCleaner.new(app)
  end
  
  def request
    Npolar::Rack::Request.new(@env)
  end
  
  context "condition?" do
    
    ["PUT", "POST"].each do |method|
      
      it "should be true when #{method}" do
        @env["REQUEST_METHOD"] = method
        subject.condition?(request).should be(true)
      end
      
    end
    
  end
  
  context "when getting a json object {}" do
  
    it "should remove key-value pairs where the value is null" do
      @env["rack.input"] = StringIO.new('{"key1":null, "key2":"value"}')
      status, headers, body = subject.handle(request)
      body.first.should == '{"key2":"value"}'
    end
    
    it "should remove key-value pairs where the value is an empty string" do
      @env["rack.input"] = StringIO.new('{"key1":"", "key2":"value"}')
      status, headers, body = subject.handle(request)
      body.first.should == '{"key2":"value"}'
    end
    
    it "should remove key-value pairs where the value is an empty json object" do
      @env["rack.input"] = StringIO.new('{"key1":{}, "key2":"value"}')
      status, headers, body = subject.handle(request)
      body.first.should == '{"key2":"value"}'
    end
    
    it "should remove key-value pairs where the value is an empty Array" do
      @env["rack.input"] = StringIO.new('{"key1":[], "key2":"value"}')
      status, headers, body = subject.handle(request)
      body.first.should == '{"key2":"value"}'
    end
    
  end 
  
  context "when getting a json array []" do  
    
    it "should remove null elements" do
      @env["rack.input"] = StringIO.new('["value", null]')
      status, headers, body = subject.handle(request)
      body.first.should == '["value"]'
    end
    
    it "should remove empty string elements" do
      @env["rack.input"] = StringIO.new('["value", ""]')
      status, headers, body = subject.handle(request)
      body.first.should == '["value"]'
    end
    
    it "should remove empty json objects" do
      @env["rack.input"] = StringIO.new('["value", {}]')
      status, headers, body = subject.handle(request)
      body.first.should == '["value"]'
    end
    
    it "should remove empty arrays" do
      @env["rack.input"] = StringIO.new('["value", []]')
      status, headers, body = subject.handle(request)
      body.first.should == '["value"]'
    end
    
  end
end
