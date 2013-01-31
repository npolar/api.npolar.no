require "spec_helper"
require "npolar/api"
require "npolar/rack/request"
require "npolar/api/solr_query"

describe Npolar::Api::SolrQuery do
  def rack_request(path="/", *args)
    env = Rack::MockRequest.env_for(path, *args)
    Npolar::Rack::Request.new(env)
  end

  context "#self.q" do
    it "blank query should yield *:*" do
      Npolar::Api::SolrQuery::q({"q" => ""}).should == "*:*"
    end

    it "foo :  bar  should yield foo:bar" do
      Npolar::Api::SolrQuery::q({"q" => "foo :  bar"}).should == "foo:bar"
    end

    it "foo: 1 to 10 should yield foo:1 TO 10" do
      Npolar::Api::SolrQuery::q({"q" => "foo : 1 to 10"}).should == "foo:1 TO 10"
    end

    it "foo should yield title:foo OR foo OR foo*" do
      Npolar::Api::SolrQuery::q({"q" => "foo"}).should == "title:foo OR foo OR foo*"
    end
  end

  context "#request" do
    it "should return a Rack::Request"
    it "should raise Exception if Rack::Request is not set"
  end


  context "range queries (from..to)" do
    before (:each) do
      @solr_query = Npolar::Api::SolrQuery.new
      @solr_query.request = rack_request("/foo?bar=0..9&north=-90.0..-60.0,60.0..90.0&not-range=123")
    end
    describe "#ranges" do

      it "#ranges should return all parameters containing .." do
        @solr_query.ranges.should == []
      end
    end
  end
end
