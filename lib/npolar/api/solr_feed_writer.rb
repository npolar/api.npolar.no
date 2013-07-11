# JSON feed writer
class Npolar::Api::SolrFeedWriter

  def self.feed(response, request)
    facets = {}

    base = request.path.gsub(/\/$/, "")+"/"
    
    if response.is_a? String
      response = JSON.parse response
    end
    
    
    if response.key? "facet_counts" and response["facet_counts"].key? "facet_ranges"
      response["facet_counts"]["facet_ranges"].each do |ranges|
        range = ranges[0]
        counts = ranges[1..-1].flatten.map {|range|
    
        #range["gap"].to_i => ranges range gap 
        range["counts"]}.flatten.each_slice(2).map {|r,c| [r,c]}
        facets[range] = counts
      end
    end
    
    if response.key? "facet_counts" and response["facet_counts"].key? "facet_fields"
      response["facet_counts"]["facet_fields"].each do |field,key_count|
        facets[field] = key_count.each_slice(2).map {|slice|[slice[0],slice[1]]}
      end
    end
    
    qtime = response["responseHeader"]["QTime"].to_i
    pagesize = response["responseHeader"]["params"]["rows"].to_i
    totalResults = response["response"]["numFound"].to_i
    
    start = response["response"]["start"].to_i
    last = start < totalResults ? start : pagesize*(totalResults/pagesize).ceil.to_i
    
    previous = start >= pagesize ? start-pagesize : false
    
    if previous.is_a? Fixnum and previous > last
      previous = last
    end
    nxt = start+pagesize > totalResults ? false : start+pagesize
    
    
    {"feed" => {
      "base" => base,
      # http://www.opensearch.org/Specifications/OpenSearch/1.1#OpenSearch_response_elements
      "opensearch" => {
        "totalResults" =>  totalResults,
        "itemsPerPage" => pagesize,
        "startIndex" => response["response"]["start"].to_i
      },
      "list" => {
        "self" => request.url,
        "next" => nxt,
        "previous" => previous,
        "first" => 0,
        "last" => last
      },
      "search" => {
        "qtime" => qtime,
        "q" => response["responseHeader"]["params"]["q"],
      },
    
      "facets" => facets,
      "entries" => response["response"]["docs"]}
    }
  end
end