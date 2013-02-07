require "spec_helper"
require "npolar/rack/change_logger"

describe Npolar::Rack::ChangeLogger do
  
  before(:each) do
    @document = '{"_id": "my_id", "_rev": "my_rev", "data": "current"}'
    @document_log = '{
      "_id": "uuid(my_id)",
      "_rev": "log_rev",
      "document": "my_id",
      "workspace": "workspace",
      "collection": "collection",
      "additional_namespaces": "",
      "changes": [{
        "name": "ruben",
        "action": "POST",
        "time": "now",
        "diff": [["+", "new", "document"]]
      }]
    }'
    
    @env = Rack::MockRequest.env_for(
      "/abc",
      "REQUEST_METHOD" => "PUT",
      "REQUEST_PATH" => "/workspace/collection/abc",
      "rack.input" => StringIO.new('[{"updated": "data"}]')
    )
    
    @status = 200
  end
  
  subject do
    app = mock( "change", :call => Npolar::Rack::Response.new(
      StringIO.new('{"_id": "defg"}'), 200, {"Content-Type" => "application/json"} ) )
    
    storage = diff_storage = Npolar::Storage::Couch.new("storage")
    
    storage.stub(:get) {[200, {"Content-Type" => "application/json"}, @document]}
    
    diff_storage.stub(:get) {[@status, {"Content-Type" => "application/json"}, @document_log]}
    diff_storage.stub(:put) {|id, data| [200, {"Content-Type" => "application/json"}, "#{id}: #{data}"]}
    
    Npolar::Rack::ChangeLogger.new(app, {:data_storage => storage, :diff_storage => diff_storage})
  end
  
  context "#condition?" do
    
    it "should trigger on PUT" do
      subject.condition?(request).should be( true )
    end
    
    it "should trigger on POST" do
      @env["REQUEST_METHOD"] = "POST"
      subject.condition?(request).should be( true )
    end
    
    it "should trigger on DELETE" do
      @env["REQUEST_METHOD"] = "DELETE"
      subject.condition?(request).should be( true )
    end
    
    ["GET", "HEAD", "TRACE", "OPTIONS", "CONNECT", "PATCH"].each do |verb|
      it "should not trigger for #{verb}" do
        @env["REQUEST_METHOD"] = verb
        subject.condition?(request).should be(false)
      end
    end
    
  end
  
  context "#handle" do
    
    it "should save changes when POSTing a new document" do
      @env = Rack::MockRequest.env_for(
        "/",
        "REQUEST_METHOD" => "POST",
        "REQUEST_PATH" => "/workspace/collection/",
        "rack.input" => StringIO.new('{"new": "document"}')      
      )
      subject.handle(request)      
    end
    
    it "should save changes when PUTing a new document" do
      @env = Rack::MockRequest.env_for(
        "/new",
        "REQUEST_METHOD" => "PUT",
        "REQUEST_PATH" => "/workspace/collection/",
        "rack.input" => StringIO.new('{"new": "document"}')      
      )
      @status = 404
      subject.handle(request)
    end  
    
    it "should save changes when PUTing an update" do
      @env = Rack::MockRequest.env_for(
        "/exisitng",
        "REQUEST_METHOD" => "PUT",
        "REQUEST_PATH" => "/workspace/collection/",
        "rack.input" => StringIO.new('{"new": "document"}')      
      )
      subject.handle(request)
    end
    
    it "should save changes when DELETEing a document" do
      @env = Rack::MockRequest.env_for(
        "/exisiting",
        "REQUEST_METHOD" => "DELETE",
        "REQUEST_PATH" => "/workspace/collection/",
        "rack.input" => StringIO.new()      
      )
      subject.handle(request)
    end
    
  end
  
  context "#protected" do
    
    context "#workspace" do
      
      it "should return the workspace" do
        subject.handle(request)
        subject.send(:workspace).should == "workspace"
      end
      
      it "should be blank if there is no workspace" do
        @env["REQUEST_PATH"] = "/abc"
        subject.handle(request)
        subject.send(:workspace).should == ""
      end
      
    end
    
    context "#collection" do
      
      it "should return the collection" do
        subject.handle(request)
        subject.send(:collection).should == "collection"
      end
      
      it "should be blank if there is no collection" do
        @env["REQUEST_PATH"] = "/workspace/abc"
        subject.handle(request)
        subject.send(:collection).should == ""
      end
      
    end
    
    context "#additional_namespaces" do
      
      it "should return a path string with the extra namespaces" do
        @env["REQUEST_PATH"] = "/workspace/collection/extra/namespace/abc"
        subject.handle(request)
        subject.send(:additional_namespaces).should == "/extra/namespace"
      end
     
    end
    
    context "#namespaces" do
      
      it "should return an Array" do
        subject.handle(request)
        subject.send(:namespaces).should be_a_kind_of( Array )
      end
      
    end
    
  end
  
  
  def request
    Npolar::Rack::Request.new(@env)
  end
  
end