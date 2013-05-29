require 'spec_helper'
require 'npolar/elasticsearch/query'

describe Npolar::ElasticSearch::Query do
  
  CONFIG = {
    :start => 5,
    :limit => 30,
    :facets => [],
    :date_facets => [],
    :filters => [],
    :sort => nil
  }
  
  subject do
    Npolar::ElasticSearch::Query.new
  end
  
  context "Basic queries" do
    
    it "should build a wildcard query if q is blank" do
      subject.build.should include(
        '"query":{"query_string":{"default_field":"_all","query":"*"}}'
      )
    end
    
    it "should add a wildcard symbol to query string searches for fuzzy matching" do
      subject.params = {'q' => 'bea'} 
      subject.build.should include(
        '"query":{"query_string":{"default_field":"_all","query":"bea bea*"}}'
      )
    end
    
    it "should not add the wildcard when the query parameter ends on a whitespace" do
      subject.params = {'q' => 'polar '} 
      subject.build.should include(
        '"query":{"query_string":{"default_field":"_all","query":"polar polar*"}}'
      )
    end
    
    it "should build a field query if receiving a q-{field}= parameter" do
      subject.params = {'q-my_field' => 'abc'} 
      subject.build.should include(
        '"query":{"query_string":{"default_field":"my_field","query":"abc"}}'
      )
    end
    
  end
  
  context "Filtered queries" do
    
    it "should build a filtered query if receiving a filter-{term}= parameter" do
      subject.params = {'q' => 'polar', 'filter-species' => 'bear'} 
      subject.build.should include(
        '"filtered":{"query":'
      )
    end
    
    it "should stack multiple filter-{term}= parameters" do
      subject.params = {'filter-species' => 'bear', 'filter-topic' => 'biology'} 
      subject.build.should include(
        '"filter":{"and":[{"term":{"species":"bear"}},{"term":{"topic":"biology"}}]}'
      )
    end
    
    it "should support multi-valued filtering" do
      subject.params = {'filter-species' => 'bear,fox'} 
      subject.build.should include(
        '"filter":{"and":[{"term":{"species":"bear"}},{"term":{"species":"fox"}}]}'
      )
    end
    
    it "should filter for a range when given a filter value containing {term}..{term}" do
      subject.params = {'filter-latitude' => '-78..-74'} 
      subject.build.should include(
        '"filter":{"and":[{"range":{"latitude":{"from":"-78","to":"-74"}}}]}'
      )
    end
    
    it "should support multivalued range filters" do
      subject.params = {'filter-latitude' => '-78..-74,78..80'} 
      subject.build.should include(
        '"filter":{"and":[{"range":{"latitude":{"from":"-78","to":"-74"}}},{"range":{"latitude":{"from":"78","to":"80"}}}]}'
      )
    end
    
    it "should build a filtered query based on a filter configuration" do
      query = Npolar::ElasticSearch::Query.new({:filters => {'iso_topic'=>'farming'}})
      query.build.should include(
        '"filter":{"and":[{"term":{"iso_topic":"farming"}}]}'
      )
    end
    
    it "should support multivalued filters through the configuration" do
      query = Npolar::ElasticSearch::Query.new({:filters => {'iso_topic'=>'farming,oceans'}})
      query.build.should include(
        '"filter":{"and":[{"term":{"iso_topic":"farming"}},{"term":{"iso_topic":"oceans"}}]}'
      )
    end
    
  end
  
  context "Facets" do
    
    it "should generate facets from the facets= parameter" do
      subject.params = {'facets' => 'latitude'} 
      subject.build.should include(
        '"facets":{"latitude":{"terms":{"field":"latitude"}}}'
      )
    end
    
    it "should generate multiple facets after facets=a,b,c" do
      subject.params = {'facets' => 'latitude,longitude'} 
      subject.build.should include(
        '"facets":{"latitude":{"terms":{"field":"latitude"}},"longitude":{"terms":{"field":"longitude"}}}'
      )
    end
    
    it "should support facets provided through the configuration" do
      query = Npolar::ElasticSearch::Query.new({:facets => ['iso_topics']})
      query.build.should include(
        '"facets":{"iso_topics":{"terms":{"field":"iso_topics"}}}'
      )
    end
    
    it "should generate date facets from the configuration hash" do
      query = Npolar::ElasticSearch::Query.new(
        {:date_facets => [{:field => :created, :interval => :year}]}
      )
      query.build.should include(
        '"facets":{"year-created":{"date_histogram":{"field":"created","interval":"year"}}}'
      )
    end
    
    it "should support mixed date facets and regular facets" do
      query = Npolar::ElasticSearch::Query.new(
        {:date_facets => [{:field => :created, :interval => :day}], :facets => ['iso_topics']}
      )
      query.build.should include(
        '"facets":{"iso_topics":{"terms":{"field":"iso_topics"}},"day-created":{"date_histogram":{"field":"created","interval":"day"}}}'
      )
    end
    
  end
  
  context "Query bounds" do
    
    it "should start with the first result when no start= parameter is specified" do
      subject.build.should include(
        '"from":0'
      )
    end
    
    it "should show the result from the specified location when given start=" do
      subject.params = {'start' => '20'} 
      subject.build.should include(
        '"from":20'
      )
    end
    
    it "should return 25 results when no limit= param is provided" do
      subject.build.should include(
        '"size":25'
      )
    end
    
    it "should set the query size when given limit=" do
      subject.params = {'limit' => '150'} 
      subject.build.should include(
        '"size":150'
      )
    end
    
    it "should only show fields specified in the limit parameter" do
      subject.params = {'fields' => 'title,summary,created,updated'} 
      subject.build.should include(
        '"fields":["title","summary","created","updated"]'
      )
    end
    
    it "should sort ascending on the field following the sort= parameter" do
      subject.params = {'sort' => 'latitude'} 
      subject.build.should include(
        '"sort":[{"latitude":"asc"}]'
      )
    end
    
    it "should sort descending if the value is preceded by a minus" do
      subject.params = {'sort' => '-latitude'} 
      subject.build.should include(
        '"sort":[{"latitude":"desc"}]'
      )
    end
    
    it "should support multivalue sorting when using comma separated values with sort=" do
      subject.params = {'sort' => 'date,latitude,-longitude'} 
      subject.build.should include(
        '"sort":[{"date":"asc"},{"latitude":"asc"},{"longitude":"desc"}]'
      )
    end
    
  end
  
  context "Configuration" do
    
    it "should run with presets if given anything else then a Hash" do
      query = Npolar::ElasticSearch::Query.new(["start"])
      query.build.should include('"from":0')
      query.build.should include('"size":25')
    end
    
    it "should show results from the starting point defined in the config" do
      query = Npolar::ElasticSearch::Query.new({:start => 20})
      query.build.should include('"from":20')
    end
    
    it "should limit the number of results based on the configuration" do
      query = Npolar::ElasticSearch::Query.new({:limit => 250})
      query.build.should include('"size":250')
    end
    
  end
  
end