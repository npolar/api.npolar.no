require "spec_helper"
require "npolar/rack/diff_logger"

describe Npolar::Rack::DiffLogger do
  before(:each) do
    @env = Rack::MockRequest.env_for("/", "REQUEST_METHOD" => "PUT")
  end 

  subject do
    app = [200, {"Content-type" => "application/json"}, [""]]
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
  end

end
