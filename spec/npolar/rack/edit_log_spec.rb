require "spec_helper"
require "npolar/rack/edit_log"

describe Npolar::Rack::EditLog do
  
  def testapp
    lambda { |env| [200, {"Content-Type" => "text/plain"}, ["testapp"] ]}
  end

  def app
    editlog
  end

  def editlog(app=nil, config={})
    app = app.nil? ? testapp : app
    if config == {}
      # todo test .call on lambdas
    end
    Npolar::Rack::EditLog.new(testapp, config)
  end
  
  def request_factory(env={})
    env = env.is_a?(String) ? {"REQUEST_METHOD" => env } : env

    merged = { "REQUEST_METHOD" => "PUT",
      "REQUEST_PATH" => "/endpoint/path/id",
      "rack.input" => StringIO.new('{"title": "Title"}')
      }.merge(env)

    env = Rack::MockRequest.env_for("/endpoint/path/id", merged)
    Npolar::Rack::Request.new(env)
  end
    
  context "#condition?" do
    
    ["DELETE", "PATCH", "POST", "PUT"].each do |verb|
      it "true on #{verb}" do
        editlog.condition?(request_factory(verb)).should == true
      end
    end
    
    ["GET", "HEAD", "TRACE", "OPTIONS", "CONNECT"].each do |verb|
      it "false on #{verb}" do
        editlog.condition?(request_factory(verb)).should == false
      end
    end
  end
  
  context "#edit" do
    # put "/endpoint", '{"title": "T1"}\n' => Stacktrace !?
    context "keys" do
      it do
        request = request_factory("PUT")
        editlog = Npolar::Rack::EditLog.new(testapp)
        response = editlog.handle(request)
        editlog.edit(request, response).keys.should ==  [:id, :server, :method, :endpoint, :path, :request, :response, :severity, :open]
      end
    end

    context "open == true" do
      it "response body is returned" do
      
        request = request_factory("PUT")
        editlog = Npolar::Rack::EditLog.new(testapp,  open: true)
        response = editlog.handle(request)

        editlog.edit(request, response)[:response][:body].should == "testapp"
        #editlog.edit(request, response)[:request][:body].should == "testapp"
      end
      it "request body is returned"

      it "endpoint is never empty" do

        request = request_factory("PUT")
        editlog = Npolar::Rack::EditLog.new(testapp,  open: true)
        response = editlog.handle(request)

        edit = editlog.edit(request, response)[:endpoint].should == "/endpoint/path"

      end
#{
#          server: "example.com",
#          method: "PUT",
#          endpoint: "/endpoint/path",
#          path: "/endpoint/path/id",
#          severity: 6,
#          open: true
#        }


    end

    context "open == false" do
      it "response body is \"\"" do
      
        request = request_factory("PUT")
        editlog = Npolar::Rack::EditLog.new(testapp,  open: false)
        response = editlog.handle(request)

        editlog.edit(request, response)[:response][:body].should == ""

      end

      it "request body is \"\""

    end
        
  end

end