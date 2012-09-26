require "spec_helper"
require "npolar/rack/request"

describe Npolar::Rack::Request do
  
  def env(path="/")
    Rack::MockRequest.env_for(path)
  end

  describe "#id" do
    it "should extract foo from foo.bar" do
      request = Npolar::Rack::Request.new env("/foo.bar")
      request.id.should == "foo"
    end

    it "should extract foo from foo.bar.bar/foo" do
      request = Npolar::Rack::Request.new env("/foo.bar.bar/foo")
      request.id.should == "foo"
    end

  end

  describe "#format" do
    context "in request path" do
  
      it "extract bar from foo.bar" do
        request = Npolar::Rack::Request.new env("/foo.bar")
        request.format.should == "bar"

      end
  
      it "extract xml from foo.xml/validate" do
        request = Npolar::Rack::Request.new env("foo.xml/validate")
        request.format.should == "xml"
      end
  
    end
  
    context "missing in the request path" do
      context "GET/HEAD" do


        it "use Accept header"
      end
    
      context "POST/PUT" do
        it "use Content-Type header"
      end
  
      context "No header" do
        it "fallback to default format"
      end
      # json if unacceptable => JSON in server/JSON in collection.default...
  
    end
  end
  

end