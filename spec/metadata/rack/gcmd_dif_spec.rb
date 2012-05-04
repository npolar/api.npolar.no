require_relative "../../spec_helper"
require "metadata/rack/gcmd_dif"

describe Metadata::Rack::GcmdDif do
  
  before do
    body = '{"Entry_Title": "my title", "Entry_ID": "myID", "Summary": {"Abstract":"my summary"}}'
    @app = lambda { |env| [200, { "Content-Type" => "application/json"}, [body]] }
    
    default_request = Rack::MockRequest.env_for("/")
    @default_body = Metadata::Rack::GcmdDif.new(@app).call(default_request).last
  end
    
  context "when receiving a GET" do
    
    it "should require a valid id" do
      invalid_request = Rack::MockRequest.env_for("/.xml")      
      invalid_body = Metadata::Rack::GcmdDif.new(@app).call(invalid_request).last
      invalid_body.should == @default_body
    end
    
    it "should return DIF xml when it receives a request with the .xml extension" do
      request = Rack::MockRequest.env_for("/mydif.xml")
      body = Metadata::Rack::GcmdDif.new(@app).call(request).last      
      body.first.should include("<Entry_ID>myID</Entry_ID>", "<Entry_Title>my title</Entry_Title")
    end
    
    it "should return DIF xml when it receives a request with the .dif extension" do
      request = Rack::MockRequest.env_for("/mydif.dif")
      body = Metadata::Rack::GcmdDif.new(@app).call(request).last
      body.first.should include("<Entry_ID>myID</Entry_ID>", "<Entry_Title>my title</Entry_Title", "<Abstract>my summary</Abstract>")
    end
    
    it "should return json when getting a request with the .json format" do
      request = Rack::MockRequest.env_for("/id.json")
      body = Metadata::Rack::GcmdDif.new(@app).call(request).last
      body.first.should include('"Entry_ID": "myID"')
    end
    
    it "should return json on a request with no format specified" do
      request = Rack::MockRequest.env_for("/mydif")
      body = Metadata::Rack::GcmdDif.new(@app).call(request).last
      body.first.should include('"Entry_ID": "myID"')
    end
    
    it "should return correct headers for requests with the .xml format" do
      request = Rack::MockRequest.env_for("/id.xml")
      status, headers, body = Metadata::Rack::GcmdDif.new(@app).call(request)
      headers.should include("Content-Type"=>"application/xml")
    end
    
    it "should return correct headers for requests with the .dif format" do
      request = Rack::MockRequest.env_for("/id.dif")
      status, headers, body = Metadata::Rack::GcmdDif.new(@app).call(request)
      headers.should include("Content-Type"=>"application/xml")
    end
    
    it "should return correct headers for requests with the .json format" do
      request = Rack::MockRequest.env_for("/mydif.json")
      status, headers, body = Metadata::Rack::GcmdDif.new(@app).call(request)
      headers.should include("Content-Type"=>"application/json")
    end
    
    it "should return correct headers for requests with no format" do
      request = Rack::MockRequest.env_for("/mydif")
      status, headers, body = Metadata::Rack::GcmdDif.new(@app).call(request)
      headers.should include("Content-Type"=>"application/json")
    end
    
    it "should return the correct Content-Length" do     
      request = Rack::MockRequest.env_for("/id.xml")
      status, headers, body = Metadata::Rack::GcmdDif.new(@app).call(request)      
      headers.should include("Content-Length"=>"#{body.first.size.to_s}")
    end   
    
  end
  
  context "when receiving a GET request with any format execept (.dif|.xml|.json|no format)" do    
    
    it "should return 406 (Not acceptable) with a random extension" do
      request = Rack::MockRequest.env_for("/mydif.sagw")
      status, headers, body = Metadata::Rack::GcmdDif.new(@app).call(request)
      status.should == 406
    end
    
    it "should return json in the body" do
      request = Rack::MockRequest.env_for("/mydif.sagw")
      body = Metadata::Rack::GcmdDif.new(@app).call(request).last
      body.first.should include('"Entry_ID": "myID"')
    end    
    
    it "should return Content-Type: application/json in the headers" do
      request = Rack::MockRequest.env_for("/mydif.sagw")
      status, headers, body = Metadata::Rack::GcmdDif.new(@app).call(request)
      headers.should include("Content-Type"=>"application/json")
    end
    
  end
    
end
