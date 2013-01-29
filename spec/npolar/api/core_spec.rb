require "spec_helper"

require "npolar/exception"
require "npolar/rack/middleware"
require "npolar/rack/request"
require "npolar/rack/response"

require "npolar/api/core"

describe 'Api::Core (accepts == formats == ["foo", bar"])' do

  def app
    Rack::Lint.new(api)
  end

  def api
    api = Npolar::Api::Core.new(nil, config)
    api.storage = storage_double
    api
  end

  def config
    {
      :accepts => ["foo", "bar"],
      :formats => ["foo", "bar"],
      :headers => { "Content-Type" => "application/bar; charset=utf-8" },
    }
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

    #storage.stub(:valid?)

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
    headers = {"Content-Type" => "foo/bar; charset=utf-8" }
    body = method
    [status, headers, body]
  end

  def rack_request(path="/")
    Npolar::Rack::Request.new(env(path))
  end

  context "Document" do

    ["GET", "HEAD", "DELETE"].each do | method |

      context "#{method} /foo.bar" do
        it "200 OK" do
          request "/foo.bar", :method => method
          last_response.status.should == 200
        end



        it "Content-Length: #{method == 'HEAD' ? "3 or missing" : method.size }" do
          request "/foo.bar", :method => method
          if last_response.headers.keys.include? "Content-Length"
            last_response.headers.should include ({"Content-Length"=>"#{method == 'HEAD' ? "3" : method.size.to_s }"})
          end
        end
      
        if method == "HEAD"
          it "Body = ''" do
            head "/foo.bar"
            last_response.body.should == ""
          end
        else
          it "Body = '#{method}'" do
            request "/foo.bar", :method => method
            last_response.body.should == method
          end
        end
      end

        context "#{method} /foo [Accept: foo/bar]" do
          it "200 OK" do
            request "/foo", { :method => method, "HTTP_ACCEPT" => "foo/bar" }
            last_response.status.should == 200
          end
        end
        context "#{method} /foo.bad" do
          it "406 Not Acceptable" do
            request "/foo.bad", :method => method
            last_response.status.should == 406
          end
        end
        context "#{method} /foo [Accept: foo/bad]" do
          it "406 Not Acceptable" do
            request "/foo", { :method => method, "HTTP_ACCEPT" => "foo/bad" }
            last_response.status.should == 406
          end
        end
        #it "Content-Type: foo/bar; charset=utf-8"


      
    end     
    
    context "PUT /foo.bar" do
  
      it "201 Created" do
        put "/foo.bar", "PUT"
        last_response.status.should == 201
      end

      it "Body = 'PUT" do
        put "/foo.bar", "PUT"
        last_response.body.should == "PUT"
      end

      it "Invalid document"  
      it "Location: URI" # after POST|PUT

      it "Remove HTTP headers not on Whitelist"

      context "without payload" do
        it "400 Bad Method" do
          put "/foo.bar"
          last_response.status.should == 400
        end
      end

      # 4xx PUT foo.bad with bar Content-Type headers?
      # 201 PUT foo with bar headers?
      # POST?
      # DELETE foo.bar === DELETE foo ?
    end

    context "POST" do
      context "/foo.bar" do
        it "201 Created" do
          post "/foo.bar", "{}", {"CONTENT_TYPE" => "foo/bar" }
          last_response.status.should == 201
        end
      end
      context "/foo.bad" do
        it "415 Unsupported Media Type" do
          post "/foo.bad", "{}", {"CONTENT_TYPE" => "foo/bad" }
          last_response.status.should == 415
        end
      end
      context "/foo [Content-Type: foo/bad]" do
        it "415 Unsupported Media Type" do
          post "/foo", "{}", {"CONTENT_TYPE" => "foo/bad" }
          last_response.status.should == 415
        end
      end
    end

    context "UNKOWN" do
      context "/foo.bar" do
        it "405 Method Not Allowed" do
          request "/foo.bar", :method => "UNKOWN"
          last_response.status.should == 405
        end
      end
    end
  end

  context "Blank id" do

    ["PUT", "DELETE"].each do | method |
      context "#{method}" do
        it "400 Bad Request" do
          request "/.bar", :method => method
          last_response.status.should == 400
        end
      end
    end
  end

  context "Storage" do
    context "Missing storage" do
        it "501 Not Implemented" do
        core = Npolar::Api::Core.new
        core.call(env("/foo.foo")).status.should == 501
      end
    end
  end

  # POST tukle med id => overstyre ID altså POST uten id for å sikre at ID = uuid
  #context "JSON" do
  #
  #  context "security" do
  #    context "PUT requests where id in path != id in body" do
  #      it "403 Forbidden" 
  #    end
  #  end  
  #
  #end

  context "Polar bears eat Exceptions" do
    it "500 Internal Server Error" do

      storage = double("Api::Storage::Dummy")
      storage.stub(:get => lambda { }) # will cause Exception

      core = Npolar::Api::Core.new(nil, :formats => ["foo", "bar"], :accepts => ["foo", "bar"], :storage => storage)
      core.call(env("/foo.bar")).status.should == 500
    end
  end

  context "Configuration" do
    context ":formats and :accepts" do
      it "String" do
        core = Npolar::Api::Core.new(nil, :formats => "zoo", :accepts => "zoo", :storage => storage_double)
        core.accepts.should == ["zoo"]
        core.formats.should == ["zoo"]
      end
      it "Array" do
        core = Npolar::Api::Core.new(nil, :formats => ["zoo","tzar"], :accepts => ["zoo","tzar"], :storage => storage_double)
        core.accepts.should == ["zoo","tzar"]
        core.formats.should == ["zoo","tzar"]
      end
      it "Proc" do
        core = Npolar::Api::Core.new(nil, :formats => lambda {|f|["zoo","tzar"]}, :accepts => lambda {|f|["zoo","tzar"]}, :storage => storage_double)
        core.accepts.should == ["zoo","tzar"]
        core.formats.should == ["zoo","tzar"]
      end
      it "Callable object" do
        class CallMe
          def call(env=nil)
            ["called"]
          end
        end
        core = Npolar::Api::Core.new(nil, :formats => CallMe.new, :accepts => CallMe.new, :storage => storage_double)
        core.accepts.should == ["called"]
        core.formats.should == ["called"]
      end
      it "storage.accepts"
      it "storage.formats"
    end
  end

end
# todo: uninitialized constant Api::Exception
# 414 Request-URI Too Long
# 10.4.14 413 Request Entity Too Large
# json spec [] => 202 accepted...