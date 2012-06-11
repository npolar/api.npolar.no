require "spec_helper"
require "api/rack/middleware"
require "api/server"

require "api/collection"

# see describe Rack::Request do
describe Api::Server do

  def app
    Rack::Lint.new(api)
  end

  def api
    api = Api::Server.new
    api.collection = collection_double
    api
  end

  def collection_double
    collection = double("Api::Collection")
    
    collection.stub(:delete => rack_response("DELETE"))
    collection.stub(:get => rack_response("GET"))
    collection.stub(:post => rack_response("POST"))
    collection.stub(:put => rack_response("PUT"))

    head_response = rack_response("GET")
    head_response[2] = []
    collection.stub(:head => head_response)
    
    collection.stub(:accepts => ["bar", "json"])
    collection.stub(:accepts? => true)

    collection.stub(:format)
    collection.stub(:format=)
    collection.stub(:formats => ["bar"])
    
    collection
  end

  def env(path="/")
    Rack::MockRequest.env_for(path)
  end

  def rack_response(m)
    status = 200
    headers = {"CONTENT_TYPE" => "foo/bar" }
    body = m
    [status, headers, body]
  end

  def rack_request(path="/")
    Rack::Request.new(env(path))
  end

  context "Resource manupulation" do

  # good format bad format no format

    ["DELETE", "GET", "HEAD"].each do | method |

      context "#{method} /foo.bar" do
        it "200 OK" do
          request "/foo.bar", :method => method
          last_response.status.should == 200
        end

        if method == "HEAD"
          it "Body = ''" do
            head "/foo.bar", {"CONTENT_TYPE" => "foo/bar" }
            last_response.body.should == ""
          end
        else
          it "Body = '#{method}'" do
            request "/foo.bar", :method => method
            last_response.body.should == method
          end
        end

        it "Content-Type: foo/bar; charset=utf-8" do
          request "/foo.bar", :method => method
          last_response.headers.should include({"Content-Type" => "application/bar; charset=utf-8"})
        end

        it "Content-Length: #{method == 'HEAD' ? "3 or missing" : method.size }" do
          request "/foo.bar", :method => method
          if last_response.headers.keys.include? "Content-Length"
            last_response.headers.should include ({"Content-Length"=>"#{method == 'HEAD' ? "3" : method.size.to_s }"})
          end
        end

        context "#{method} /foo.bad" do
          # http://tools.ietf.org/html/rfc2616#section-10.4.16
          it "406 Not Acceptable" do 
            request "/foo.bad", :method => method
            last_response.status.should == 406 
          end

          unless "HEAD" == method
            it "Body = '{ \"error\": ... }'" do 
              request "/foo.bad", :method => method
              error = JSON.parse(last_response.body) 
              error.keys.should == ["error"]
            end
          end
        end
      end     
    end
    context "PUT /foo.bar" do
      #it "foo" do
        #  put "foo", "PUT"
        #  last_response.body.should == "PUT"
        #  last_response.status.should == 200
      #end
  
      it "200 OK" do
        put "foo.bar", "PUT"
        last_response.body.should == "PUT"
        last_response.status.should == 200
      end

          it "Body = 'PUT" do
            put "/foo.bar", "PUT"
            last_response.body.should == "PUT"
          end

      context "without payload" do
        it "400 Bad Request" do
          put "foo"
          last_response.status.should == 400
        end
      end

      # PUT foo.bad with bar headers?
      # PUT foo with bar headers?
      # POST?
      context "/foo.bad" do
        # http://tools.ietf.org/html/rfc2616#section-10.4.16
        it "415 Unsupported Media Type" do 
          put "foo.bad", "text"
          last_response.status.should == 415
        end
      end
 
  


    end

  end

    # DELETE foo.bar === DELETE foo ?

  #context "Bad format" do
  #  ["DELETE", "GET", "HEAD"].each do | method |
  #   
  #  end
  #
  #  
  #end

    
  describe "#acceptable_format?" do

    it "Good format" do
      acceptable = api.acceptable_format? rack_request("foo.bar")
      acceptable.should == true
    end

    it "Bad format" do
      acceptable = api.acceptable_format? rack_request("foo.bad")
      acceptable.should == false
    end

    it "'' (No format)" do
      acceptable = api.acceptable_format? rack_request("foo")
      acceptable.should == true
    end

  end

  describe "#id" do
    
      it "should extract foo from foo.bar" do
        request = Rack::Request.new(env("foo.bar"))
        api = Api::Server.new
  
        id = api.id request
        id.should == "foo"
      end
  
  end

  describe "#format" do
    context "in request path" do

      it "extract bar from foo.bar" do
        format = api.format rack_request("foo.bar")
        format.should == "bar"
      end

      it "extract xml from foo.xml/validate" do
        format = api.format rack_request("foo.xml/validate")
        format.should == "xml"
      end

    end

    context "missing in the request path" do
      it "use format from Accept header" do
        r = rack_request
        r.env["HTTP_ACCEPT"] = "foo/bar"
        api.format(r).should == "bar"
      end

      it "or fallback to default format" do
        api.format(rack_request).should == "json"
      end
      # json if unacceptable => JSON in server/JSON in collection.default...

    end
    
  end

  context "Server errors" do
    it "No collection should give server error" 
  end

  context "JSON" do
    context "security" do
      context "PUT requests where id in path != id in body" do
        it "403 Forbidden" 
      end
    end

    context "Arrays of documents" do
      it "should accept POSTing multiple documents" do
        post "/foo.bar", "[]"
        last_response.status.should == 202

      end
    end

  end

end
# todo: uninitialized constant Api::Exception
# 414 Request-URI Too Long
# 10.4.14 413 Request Entity Too Large
# json spec [] => 202 accepted...
#   