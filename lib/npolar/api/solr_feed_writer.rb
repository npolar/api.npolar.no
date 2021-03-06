require "addressable/uri"

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
        range_info = ranges[1..-1][0]
        range_info["counts"] = range_info["counts"].each_slice(2).map {|slice|[slice[0],slice[1]]}
        facets[range] = range_info
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
    last = (start >= totalResults) ? start : pagesize*(totalResults/pagesize.ceil)
        
    previous = start >= pagesize ? start-pagesize : false
    if previous.is_a? Fixnum and previous > last
      previous = last
    end
    nxt = start+pagesize > totalResults ? false : start+pagesize

    # parse everything in the url
    addr = Addressable::URI.parse(request.url)

    # post-process facets, to get them into proper opensearch format
    facets = facets.map { |name, info_list |
      
      if info_list.is_a? Hash and info_list.key? "counts" and info_list.key? "gap"
        counts = info_list["counts"]
        gap = info_list["gap"]
        { name => counts.map { |c|
          { "term" => range_facet_href(name, c[0], gap), "count" => c[1], "uri" => self.facet_url(addr, name, c[0], gap) } }
        }
      else
      
        { name => info_list.map { |info|
              { "term" => info[0], "count" => info[1], "uri" => self.facet_url(addr, name, info[0]) } }
        }
      end
      }

    # uri to self
    self_uri = addr.to_str

    # figure out next uri
    if nxt == false
      next_uri = false
    else
      addr.query_values = addr.query_values.merge({'start' => nxt})
      next_uri = addr.to_str
    end

    # figure out prev uri
    if previous == false
      previous_uri = false
    else
      addr.query_values = addr.query_values.merge({'start' => previous})
      previous_uri = addr.to_str
    end
    
    
    addr.query_values = addr.query_values.merge({'start' => last})
    last_uri = addr.to_str
    
    addr.query_values = addr.query_values.merge({'start' => 0})
    first_uri = addr.to_str
    
    feed = {
      "feed" => {
      "base" => base,
      # http://www.opensearch.org/Specifications/OpenSearch/1.1#OpenSearch_response_elements
      "opensearch" => {
        "totalResults" =>  totalResults,
        "itemsPerPage" => pagesize,
        "startIndex" => response["response"]["start"].to_i
      },
      "links" => [
        { rel: "self", href: self_uri, type: "application/json" },
        { rel: "next", href: next_uri, type: "application/json" },
        { rel: "previous", href: previous_uri, type: "application/json" },
        { rel: "first", href: first_uri, type: "application/json" },
        { rel: "last", href: last_uri, type: "application/json" }
      ],
      "search" => {
        "qtime" => qtime,
        "q" => response["responseHeader"]["params"]["q"],
      },
      "entries" => response["response"]["docs"],
      "facets" => facets
      }
    }
    
    if request["variant"] != "atom"
      feed["feed"].delete "links"
      feed["feed"]["list"] = {
        "self" => self_uri,
        "next" => next_uri,
        "previous" => previous_uri,
        "first" => first_uri,
        "last" => last_uri
      }
    end
    
    feed
  end
  
  def self.facet_url(addr, name, val, gap=nil)
    _addr = addr.clone
    if gap.nil?
      href = val
    else
      href = range_facet_href(name, val, gap)
    end
  
    _addr.query_values = _addr.query_values.merge({"filter-#{name}" => href })
    return _addr.to_str
  end
  
  def self.geojson_feature_collection(response,request, lat_field="latitude", long_field="longitude", geometry="Point")
    if not ["Point", "LineString"].include? geometry
      raise ArgumentError, "Unsupported GeoJSON geometry type: #{geometry}"
    end
    feed = feed(response, request)["feed"].reject {|k,v| k =~ /^entries/}
    if "Point" == geometry
      gj = { type: "FeatureCollection",
        features: response["response"]["docs"].map {|d|
          latitude = d[lat_field].is_a?(Array) ? d[lat_field][0] : d[lat_field]
          longitude = d[long_field].is_a?(Array) ? d[long_field][0] : d[long_field]
          
          { geometry: { type: geometry, coordinates: [longitude,latitude]},
            type: "Feature", id: d["id"], properties: d #.select {|k,v| v.nil? or v.is_a?(String) or v.is_a? Float or v.is_a? Fixnum }
          }
        }
      }
    elsif
      first = response["response"]["docs"].first
      
      gj = { type: "Feature", geometry: { type: "LineString",
          :coordinates => response["response"]["docs"].map { |d|
            latitude = d[lat_field].is_a?(Array) ? d[lat_field][0] : d[lat_field]
            longitude = d[long_field].is_a?(Array) ? d[long_field][0] : d[long_field]
            [longitude, latitude]
          }
        },
        # Note: The client needs to use fields and filters so that this makes sense,
        # ie. only returning the fields/properties that are common to all documents in the response      
        properties: first
      }
    end
    gj["feed"] = feed
    gj
    
  end

  def self.range_facet_href(name, val, gap)
    
    if val =~ Npolar::Rack::Solrizer::INTEGER_REGEX
      val = val.to_i
      nxt = val + gap.to_i
    elsif val =~ Npolar::Rack::Solrizer::FLOAT_REGEX
      val = val.to_f
      nxt = val + gap.to_f
      
      # Get rid of unwanted (in the UI) precision
      if val.to_i.to_f == val and nxt == nxt.to_i.to_f
        val = val.to_i
        nxt = nxt.to_i
      end
    end
   
    if gap =~ /[+](\d+)YEAR(S)?$/
      gap = ($1.to_i)-1 # because otherwise we get 2006-2007 (2 years) if gap is +1YEAR
      
      val = DateTime.parse(val).year
      nxt = val + gap
    end
    
    if val != nxt
      "#{val}..#{nxt}"
    else
      val # because 2014 means 2014..2014 => [2014-01-01T00:00:00Z TO 2014-12-31T23:59:59.666666Z]
    end
    
  
  end

end