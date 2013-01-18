require "spec_helper"
require "npolar/rack/diff_logger"

describe Npolar::Rack::DiffLogger do
  before(:each) do
    @env = Rack::MockRequest.env_for("/", 
      "REQUEST_METHOD" => "PUT",
      "REQUEST_URI" => "/abc/def/foo.json",
      "rack.input" => StringIO.new('{ "_id":"org-polarresearch-303","_rev":"4-a0f42d79ee71b299b0917a634ddb7732","a" : "2", "b" : "3"}')
    )
  end 

  subject do
    app = mock( "foobar", :call => Npolar::Rack::Response.new(
             StringIO.new(""), 200, {"Content-Type" => "application/json"} ) )  
    data_storage = Npolar::Storage::Couch.new("diffs")
    diff_storage = Npolar::Storage::Couch.new("metadata_dataset")

    data_storage.stub(:get) { '{ "_id":"org-polarresearch-303","_rev":"4-a0f42d79ee71b299b0917a634ddb7732","a" : "1", "b" : "2"}' }
    diff_storage.stub(:post) { [200, {"Content-type" => "application/json"}, [""]] }

    Npolar::Rack::DiffLogger.new(app, { :data_storage => data_storage, :diff_storage => diff_storage })
  end
  
  context "#condition?" do
    
    it "should be true with method PUT" do
      subject.condition?( Npolar::Rack::Request.new(@env) ).should be(true)
    end
    
    it "should be true with method DELETE" do
      @env["REQUEST_METHOD"] = "DELETE"
      subject.condition?( Npolar::Rack::Request.new(@env) ).should be(true)
    end
    
    it "should be false when GET" do
      @env["REQUEST_METHOD"] = "GET"
      subject.condition?( Npolar::Rack::Request.new(@env) ).should be(false)
    end

    it "should be false when POST" do
      @env["REQUEST_METHOD"] = "POST"
      subject.condition?( Npolar::Rack::Request.new(@env) ).should be(false)
    end
    
  end
  
  context "#handle" do
    it "PUT should not result in 404" do
      status, headers, body = subject.handle(Npolar::Rack::Request.new(@env))
      status.should_not == 404
    end

    it "DELETE should not result in 404" do
      @env["REQUEST_METHOD"] = "DELETE"
      status, headers, body = subject.handle(Npolar::Rack::Request.new(@env))
      status.should_not == 404
    end

  end

end
