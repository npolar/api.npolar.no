require_relative "../../spec_helper"
require "metadata/rack/gcmd_dif"

describe Metadata::Rack::GcmdDif do
  
  before do
    body = '{"Entry_Title": "my title", "Entry_ID": "myID", "Summary": {"Abstract":"my summary"}}'
    @app = lambda { |env| [200, { "Content-Type" => "application/json"}, [body]] }
    
    default_request = Rack::MockRequest.env_for("/")
    @default_body = Metadata::Rack::GcmdDif.new(@app).call(default_request).last
  end
    
  context "when receiving a GET with dif or xml format" do
    
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
    
  end
  
  context "when receiving a request with any format execept (.dif|.xml) or no format" do
    
    it "should return json with no extension" do
      request = Rack::MockRequest.env_for("/mydif")
      body = Metadata::Rack::GcmdDif.new(@app).call(request).last
      body.first.should include('"Entry_ID": "myID"')
    end
    
    it "should return 406 (Not acceptable) with a random extension" do
      request = Rack::MockRequest.env_for("/mydif.sagw")
      status, headers, body = Metadata::Rack::GcmdDif.new(@app).call(request)
      status.should == 406
    end
    
  end
end
