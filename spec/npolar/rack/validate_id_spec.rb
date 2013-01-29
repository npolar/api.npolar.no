require "spec_helper"
require "npolar/rack/validate_id"

describe Npolar::Rack::ValidateId do

  before(:each) do
    @validator = Npolar::Rack::ValidateId.new()
     end

  context "#id" do
    it "abc/def/ghi ==> id of ghi" do
      env = Rack::MockRequest.env_for(
        "/test.json",
        "PATH_INFO" => "abc/def/ghi",
      )
      request = Npolar::Rack::Request.new(env)

      @validator.id(request).should == "ghi"
    end
  end

  context "#condition?" do
    it "id starting with_ should yield true" do
      env = Rack::MockRequest.env_for(
        "/test.json",
        "PATH_INFO" => "abc/_asdf"
      )
      request = Npolar::Rack::Request.new(env)

      @validator.condition?(request).should == true
    end

    it "id containing blanks should yield true" do
      env = Rack::MockRequest.env_for(
        "/test.json",
        "PATH_INFO" => "abc/asdf asdf"
      )
      request = Npolar::Rack::Request.new(env)

      @validator.condition?(request).should == true
    end
  end

end
