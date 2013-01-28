require "spec_helper"
require "npolar/api/solr_query.rb"

describe Npolar::Api::SolrQuery do
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
end
