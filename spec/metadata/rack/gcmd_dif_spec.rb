require_relative "../../spec_helper"
require "metadata/rack/gcmd_dif"

describe Metadata::Rack::GcmdDif do
  
  before do
    body = '{"Entry_Title": "my title", "Entry_ID": "myID", "Summary": {"Abstract":"my summary"}}'
    @app = lambda { |env| [200, { "Content-Type" => "application/json"}, [body]] }
  end
  
  context "when receiving a GET with dif or xml format" do
    
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
    
    it "should return json with a random extension" do
      request = Rack::MockRequest.env_for("/mydif.sagw")
      body = Metadata::Rack::GcmdDif.new(@app).call(request).last
      body.first.should include('"Entry_Title": "my title"')
    end
    
  end
end
