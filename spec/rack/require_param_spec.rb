require "spec_helper"
require "api/rack/middleware"
require "api/rack/require_param"

describe Api::Rack::RequireParam do

  def testapp
    lambda { |env| [200, {}, [] ]}
  end

  def app(config={})
    Api::Rack::RequireParam.new(testapp, config)
  end

  context "config" do
    it "should raise ArgumentError on unknown keys" do
      lambda {
        app({:bad => :key, :params => []})
      }.should raise_error(ArgumentError, /bad/)
    end

    it "should not raise ArgumentError if all keys are known" do
      lambda {
        app({:params => [], :except => nil})
      }.should_not raise_error
    end

    it "should not trigger if config is empty" do
      env = Rack::MockRequest.env_for("/")
      app.call(env)[0].should == 200
    end
  end

  context "#only_valid_keys?" do
    it "true if all keys are valid" do
      app.only_valid_keys?([:foo, :bar], [:foo, :bar]).should == true
    end
    it "false if any key is invalid" do
      app.only_valid_keys?(["fu", :bar], [:foo, :bar]).should == false
    end
  end

  context "#required_params" do
    it "are [] by default" do
      app.required_params.should == []
    end

    it "are set via config[:params]" do
      app = Api::Rack::RequireParam.new(nil, {:params => ["foo", "bar"]})
      app.required_params.should == ["foo", "bar"]
    end
  end

  context "#missing_params(request)" do
    it "should return array of missing params" do
      env = Rack::MockRequest.env_for("/?foo=foo&bar=&fu")
      request = Rack::Request.new(env)
      app({:params => ["foo", "bar", "fu"]}).missing_params(request).should == ["bar", "fu"]
    end
  end

end