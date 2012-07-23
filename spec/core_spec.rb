require "spec_helper"

require "npolar/exception"
require "npolar/rack/middleware"
require "npolar/rack/request"
require "npolar/rack/response"

require "npolar/api/core"


# see describe Rack::Request do
describe 'Api::Core (accepts == formats == ["foo", bar"])' do

  def app
    Rack::Lint.new(api)
  end

  def api
    config = {
      :accepts => ["foo", "bar"],
      #:format => "bar",
      :formats => ["foo", "bar"],
      :headers => { "Content-Type" => "application/bar; charset=utf-8" },
    }
    api = Npolar::Api::Core.new(nil, config)
    api.storage = storage_double
    api
  end

  def storage_double
    storage = double("Api::Storage::Dummy")
    
    storage.stub(:delete => rack_response("DELETE"))
    storage.stub(:get => rack_response("GET"))
    storage.stub(:post => rack_response("POST"))
    storage.stub(:put => rack_response("PUT"))

    head_response = rack_response("GET")
    head_response[2] = []
    storage.stub(:head => head_response)
    
    storage.stub(:accepts => ["foo", "bar"])
    storage.stub(:accepts?) do | format|
      storage.accepts.include? format
    end


    storage.stub(:format)
    storage.stub(:format=)
    storage.stub(:media_format=)
    storage.stub(:formats => ["foo", "bar"])
    
    storage
  end

  def env(path="/", *args)
    Rack::MockRequest.env_for(path, *args)
  end

  def rack_response(method)
    
    status = 200
    if method =~ /POST|PUT/
      status = 201
    end
    headers = {"CONTENT_TYPE" => "foo/bar" }
    body = method
    [status, headers, body]
  end

  def rack_request(path="/")
    Api::Rack::Request.new(env(path))
  end

  context "Document" do

    ["GET", "HEAD", "DELETE"].each do | method |

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
      end


    end     
    
    context "PUT /foo.bar" do
      #it "foo" do
        #  put "foo", "PUT"
        #  last_response.body.should == "PUT"
        #  last_response.status.should == 200
      #end
  
      it "201 Created" do
        put "/foo.bar", "PUT"
        last_response.status.should == 201
      end

      it "Body = 'PUT" do
        put "/foo.bar", "PUT"
        last_response.body.should == "PUT"
      end

      it "Location: URI"

#ch@birkafjell:~$ curl -i -X PUT -d@/tmp/x http://localhost:9393/metadata/dataset/gps.xml -H "Content-Type: application/xml"
#oops Server: CouchDB/1.0.1 (Erlang OTP/R14B)
#oops Location: http://localhost:5984/metadata_dataset/gps


      context "without payload" do
        it "412 Precondition Failed" do
          put "/foo.bar"
          last_response.status.should == 412
        end
      end

      # PUT foo.bad with bar headers?
      # PUT foo with bar headers?
      # POST?
      #context "PUT /foo.bad" do
      #  # http://tools.ietf.org/html/rfc2616#section-10.4.16
      #  it "415 Unsupported Media Type" do 
      #    put "foo.bad", "text", {"Content-Type" => "foo/bad"}
      #    last_response.status.should == 415
      #  end
      #end
      #
      #context "POST [Content-Type: foo/bad]"
  


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

    
  #describe "#acceptable? format" do
  #
  #  it "Good format" do
  #    acceptable = api.acceptable? "foo"
  #    acceptable.should == true
  #  end
  #
  #  it "Bad format" do
  #    acceptable = api.acceptable? "bad"
  #    acceptable.should == false
  #  end
  #
  #  it "'' (No format)" do
  #    acceptable = api.acceptable? ""
  #    acceptable.should == true
  #  end
  #
  #end

      #
      #context "#{method} /foo.bad" do
      #  # http://tools.ietf.org/html/rfc2616#section-10.4.16
      #  it "406 Not Acceptable" do 
      #    request "/foo.bad", :method => method
      #    last_response.status.should == 406 
      #  end
      #
      #  unless "HEAD" == method
      #    it "Body = '{ \"error\": ... }'" do 
      #      request "/foo.bad", :method => method
      #      error = JSON.parse(last_response.body) 
      #      error.keys.should == ["error"]
      #    end
      #  end
      #end

  context "POST" do
      it "/foo.bar" do
        post "/foo.bad", "{}", {"CONTENT_TYPE" => "foo/bar" }
        last_response.status.should == 201
      end
      it "/foo.bad" do
        post "/foo.bad", "{}", {"CONTENT_TYPE" => "foo/bad" }
        last_response.status.should == 415
      end
    end

  context "Server errors" do
    it "No storage should give server error" 
  end

  context "JSON" do
    
    before do
      
      @api = Npolar::Api::Core.new
      @api
    end

    context "security" do
      context "PUT requests where id in path != id in body" do
        it "403 Forbidden" 
      end
    end

    context "POST multiple documents" do
      it "202 Accepted" do
        env("/foo.bar", [ '[{"id": "foo"}, {"id": "bar"}]', {"CONTENT_TYPE" => "application/json" } ])
        @api.call(env)
        last_response.body.should == 202
      end
      it "POST [{..}, {..}]"
    end

    

  end

end
# todo: uninitialized constant Api::Exception
# 414 Request-URI Too Long
# 10.4.14 413 Request Entity Too Large
# json spec [] => 202 accepted...