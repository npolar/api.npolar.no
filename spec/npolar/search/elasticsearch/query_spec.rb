require 'spec_helper'
require 'npolar/search/query_builder'

describe Npolar::Search::ElasticSearch::Query do
  
  CONFIG = {
    :start => 5,
    :limit => 30,
    :facets => [],
    :date_facets => [],
    :filters => [],
    :sort => nil
  }
  
  subject do
    Npolar::Search::QueryBuilder.new
  end
  
  context "Basic queries" do
    
    it "should build a wildcard query if q is blank" do
      subject.build_query.should include(
        '"query":{"query_string":{"default_field":"_all","query":"*"}}'
      )
    end
    
    it "should add a wildcard symbol to query string searches for fuzzy matching" do
      subject.parse( {'q' => 'bea'} )
      subject.build_query.should include(
        '"query":{"query_string":{"default_field":"_all","query":"bea*"}}'
      )
    end
    
    it "should not add the wildcard when the query parameter ends on a whitespace" do
      subject.parse( {'q' => 'polar '} )
      subject.build_query.should include(
        '"query":{"query_string":{"default_field":"_all","query":"polar*"}}'
      )
    end
    
    it "should build a field query if receiving a q-{field}= parameter" do
      subject.parse( {'q-my_field' => 'abc'} )
      subject.build_query.should include(
        '"query":{"query_string":{"default_field":"my_field","query":"abc"}}'
      )
    end
    
  end
  
  context "Filtered queries" do
    
    it "should build a filtered query if receiving a filter-{term}= parameter" do
      subject.parse( {'q' => 'polar', 'filter-species' => 'bear'} )
      subject.build_query.should include(
        '"filtered":{"query":'
      )
    end
    
    it "should stack multiple filter-{term}= parameters" do
      subject.parse( {'filter-species' => 'bear', 'filter-topic' => 'biology'} )
      subject.build_query.should include(
        '"filter":{"and":[{"term":{"species":"bear"}},{"term":{"topic":"biology"}}]}'
      )
    end
    
    it "should filter for a range when given a filter value containing {term}..{term}" do
      subject.parse( {'filter-latitude' => '-78..-74'} )
      subject.build_query.should include(
        '"filter":{"and":[{"range":{"latitude":{"from":"-78","to":"-74"}}}]}'
      )
    end
    
  end
  
  context "Facets" do
    
    it "should generate facets from the facet-{name}= parameter" do
      subject.parse( {'facet-lat' => 'latitude'} )
      subject.build_query.should include(
        '"facets":{"lat":{"terms":{"field":"latitude"}}}'
      )
    end
    
  end
  
  context "Query bounds" do
    
    it "should start with the first result when no start= parameter is specified" do
      subject.build_query.should include(
        '"from":0'
      )
    end
    
    it "should show the result from the specified location when given start=" do
      subject.parse( {'start' => '20'} )
      subject.build_query.should include(
        '"from":20'
      )
    end
    
    it "should return 25 results when no limit= param is provided" do
      subject.build_query.should include(
        '"size":25'
      )
    end
    
    it "should set the query size when given limit=" do
      subject.parse( {'limit' => '150'} )
      subject.build_query.should include(
        '"size":150'
      )
    end
    
    it "should only show fields specified in the limit parameter" do
      subject.parse( {'fields' => 'title,summary,created,updated'} )
      subject.build_query.should include(
        '"fields":["title","summary","created","updated"]'
      )
    end
    
    it "should sort ascending on the field following the sort= parameter" do
      subject.parse( {'sort' => 'latitude'} )
      subject.build_query.should include(
        '"sort":[{"latitude":"asc"}]'
      )
    end
    
    it "should sort descending if the value is preceded by a minus" do
      subject.parse( {'sort' => '-latitude'} )
      subject.build_query.should include(
        '"sort":[{"latitude":"desc"}]'
      )
    end
    
    it "should support multivalue sorting when using comma separated values with sort=" do
      subject.parse( {'sort' => 'date,latitude,-longitude'} )
      subject.build_query.should include(
        '"sort":[{"date":"asc"},{"latitude":"asc"},{"longitude":"desc"}]'
      )
    end
    
  end
  
  context "Configuration" do
    
    it "should run with presets if given anything else then a Hash" do
      qbuilder = Npolar::Search::QueryBuilder.new(["start"])
      qbuilder.build_query.should include('"from":0')
      qbuilder.build_query.should include('"size":25')
    end
    
    it "should show results from the starting point defined in the config" do
      qbuilder = Npolar::Search::QueryBuilder.new({:start => 20})
      qbuilder.build_query.should include('"from":20')
    end
    
    it "should limit the number of results based on the configuration" do
      qbuilder = Npolar::Search::QueryBuilder.new({:limit => 250})
      qbuilder.build_query.should include(
        '"size":250'
      )
    end
    
  end
  
end