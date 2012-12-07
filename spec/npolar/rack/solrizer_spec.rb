require "spec_helper"
require "npolar/rack/middleware"
require "npolar/rack/solrizer"
require "yajl/json_gem"

describe Npolar::Rack::Solrizer do

  SOLR = "http://solr.example.com:8983/solr"

  subject(:solrizer) {
    Npolar::Rack::Solrizer.uri = nil
    solrizer = Npolar::Rack::Solrizer.new(testapp, :core => SOLR)
    solrizer.rsolr = rsolr
    solrizer
  }

  def app
    solrizer
  end

  context "Solr URI" do

    before do @s = Npolar::Rack::Solrizer.new end

    context "No Solr class URI" do
      it "default Solr URI is http://localhost:8983/solr" do
        @s.uri.should =~ /http\:\/\/localhost\:8983\/solr(\/)?/
      end
  
      it "core is appended to Solr URI" do
        s = Npolar::Rack::Solrizer.new
        s.core = "core2/path"
        s.uri.should == "http://localhost:8983/solr/core2/path"
      end
  
      it "#core == #{SOLR}" do
        solrizer.core.should == SOLR
      end
  
      it "#uri == #{SOLR}" do
        solrizer.uri.should == SOLR
      end
    end

    context "Solr class URI is #{SOLR}" do
      before do Npolar::Rack::Solrizer.uri = SOLR end

      it "#core == new" do
        s = Npolar::Rack::Solrizer.new(nil, :core => "new")
        s.core.should == "new"
      end

      it "#uri == #{SOLR}/new" do
        s = Npolar::Rack::Solrizer.new(nil, :core => "new")
        s.uri.should == "#{SOLR}/new"
      end
    end

  end

  context "Search [GET]" do

    it "searching with ?q= should return a JSON feed" do
      get "/?q="
      JSON.parse(last_response.body).should == {"feed"=>{"opensearch"=>{"totalResults"=>10,"itemsPerPage"=>2,"startIndex"=>0},
        "list"=>{"self"=>"http://example.org/?q=","next"=>2,"previous"=>false,"first"=>0,"last"=>0},
        "search"=>{"qtime"=>8,"q"=>"*:*"},
        "facets"=>{"field1"=>[["facet1",10],["facet2",5],["facet3",1]]},
        "entries"=>[
          {"id"=>"id0","title"=>"Title Zero","east"=>34.13,"north"=>78.22},
          {"id"=>"id1","title"=>"Title One","east"=>34.13,"north"=>78.22}]}
        }
    end

    it "Only GET should trigger search"

    it "#search should search for GET param q and return a Solr Ruby response object" do
      s = solrizer
      s.request = Npolar::Rack::Request.new(Rack::MockRequest.env_for("/?q=search"))
      s.search.should == solr_search_response
    end
    
    #facets - from request
    #facets- from instance
    #merging requested/instance facets
    #facets on/off
    #ranges - queries
    #ranges - facets
    #defaults
    
    context "Save [PUT]" do
      it "should call JSON update"  
    end
  end

  protected

  def testapp
    lambda { |env| [200, {}, [] ]}
  end
  
  def rsolr() # add support for diff responses
    rsolr = mock("RSolr")
    rsolr.stub(:get).and_return(solr_search_response)
    rsolr
  end

  def solr_search_response
    JSON.parse( File.read( "spec/data/solr-response.json" ) )
  end

end