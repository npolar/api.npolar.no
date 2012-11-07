# encoding: utf-8 
module Views
  module Api  
    class Index < Npolar::Mustache::JsonView

      def initialize(app=nil)
        @app = app
        @hash = { "_id" => "api_index",
          #:workspaces => (Npolar::Api.workspaces - Npolar::Api.hidden_workspaces).map {|w| {:href => w, :title => w }},
          :form => {:placeholder => "Norwegian Polar Data", :href => "", :id => "api",
          :source => '.json?q={query}&limit=20&callback={callback}' },
          :limit => 30,
          :svc => { :search => [
            {:title => "Biology", :href => "/biology/?q="},
            #{:title => "Ecotox", :href => "/ecotox/?q="},
            {:title => "Map", :href => "/map/archive?q="},
            #{:title => "Metadata ", :href => "/metadata/?q="},
            {:title => "Monitoring ", :href => "/monitoring/indicator?q="},
            {:title => "Org", :href => "/org/?q="},
            #{:title => "Oceanography", :href => "/oceanography/?q="},
            {:title => "Person", :href => "/person/?q="},
            {:title => "Placename", :href => "/placename/?q="},
            {:title => "Polar bear", :href => "/polar-bear/reference/?q="},
            {:title => "Project", :href => "/project/?q="},
            {:title => "Rapportserie", :href => "/rapportserie/105/?q="},
            #{:title => "Sighting", :href => "/sighting/fauna?q="}
            #{:title => "Seaice"},
            #{:title => "Tracking"}
            ]
},
          :welcome_article => '
<article id="welcome" class="row-fluid">
  
  <section class="span4"><h4>About</h4><p>You&apos;ve reached the <a href="http://npolar.no">Norwegian Polar Institute</a>&apos;s <strong>searchable data</strong> storage service.</p>
  
  <p><strong>Notice: </strong> The service is in <strong>alpha</strong>. We are harmonising schemas and injecting data from legacy systems.
  This means that some keys (field names) and consequently links to search results are likely to change.</p></section>
  <section class="span8">

  <h4>Search API</h4>
  <p>Search by using the <code>GET</code> parameter <code>q</code>, as in:
  <a href="/?q=Polar+bears">/?q=Polar+bears</a></p>

  <p>The default response is a <a href="http://json.org">JSON</a> feed object (@todo see example), but in web browsers
or for clients that send <code>Accept: text/html</code>, results are rendered in a data browser with powerful facet filtering (drill-down).
</p>

  <p>The search API follows the <a href="http://www.opensearch.org/">OpenSearch</a> specification (@todo see description), a brief rundown of opensearch:Url attribute mappings:
  <dl class="dl-horizontal">
    <dt>searchTerms</dt><dd><a href="">q</a></dd>
    <dt>count</dt><dd><a href="">limit</a></dd>
    <dt>startOffset</dt><dd>start</dd>
  </dl>

"limit The "count" parameter Replaced with the number of search results per page desired by the search client.
The "startIndex" parameter Replaced with the index of the first search result desired by the search client.

  The "startPage" parameter

Response formats other than JSON are in the works, including <a href="http://tools.ietf.org/html/rfc4287">Atom</a>/<a href="http://tools.ietf.org/html/rfc5023">Atom Publishing Protocol</a>
  (with embedded OpenSearch and <a href="http://georss.org/">GeoRSS</a> elements), CSV, and more.</p>
 
<p>Search is powered by Apache Solr.</p>

  <hr/>
  <h4>Document API</h4>
  <p>authorized users to create, update and delete individual 
  <p>The document API is a REST-style data store with a few nifty features:

independent deployable components 
  <ul>
    <li>Persistent URIs</li>
    <li>Schemas and data validation</li>
    <li>Versioning</li>
    <li>Edit logs</li>
    <li>Indexing</li>
    <li>Authentication/Authorization</li>
  </ul>
</p>

<p>The storage layer is flexible, currently we use CouchDB to hold the following collections:
  <ul>
    <li><a href="/metadata/dataset">Discovery-level dataset metadata</a></li>
    <li>Ecotox (coming soon™)</li>
    <li>Seaice (coming soon™)</li>
  </ul>
</p>
  </section>
</article>',
          :data => { :workspaces => Npolar::Api.workspaces }
        }
        #merge ayyt
      end

      def call(env)
        @template = nil
        @request = request = Npolar::Rack::Request.new(env)
        @hash[:self] = request.url

        @hash[:base] = request.url and ["GET", "HEAD"].include? request.request_method

        if request["q"]
          @hash[:welcome_article] = nil
          @hash[:bbox] = request["bbox"]
          @hash[:dtstart] = request["dtstart"]
          @hash[:dtend] = request["dtend"]
          @hash[:next] = 
          @hash[:form][:placeholder] = request.script_name.split("/").map {|p| p.capitalize+" "}.join.gsub(/^\s+/, "")
        end

        if request["fq"]
          
          fq = request.multi("fq").map {|fq|
            k,v = fq.split(":")
            {:filter => k, :value => CGI.unescape(v) }
          }
          @hash[:fq]=fq.uniq
          @hash[:filters?] = true
          @hash[:collection_uri] = request.script_name
        end

        unless "html" == request.format
          feed = @app.call(env)
        else
          super # ie render
        end
      end

      def head_title
        "api.npolar.no"
      end
          

      def h1_title
        "<a title=\"api.npolar.no\" href=\"/\">api</a>.npolar.no"
      end

      def nav
        workspaces
      end

      def placeholder
        request.url.split("/").join(" ")
      end


      def document_api?(w)
        case w.to_sym
          when :biology, :ecotox, :metadata, :oceanograophy, :seaice, :tracking then true
          else false
        end
      end

      def collection_badge(collection)
        case collection
          when "geoname", "placename" then "badge badge-success"
          else "badge"
        end
      end


      def entries
        feed(:entries).map {|e| {:title => e[:title]||e[:title_ss], :id => e[:id], :json => e.to_json , :collection => e[:collection], :badge => collection_badge(e[:collection]) } }
      end

      def entries_size
        entries.size
      end

      def results?
        totalResults > 0
      end

      def facets
        facets = feed(:facets).map {|field,v|
          {:title => field, :counts => v.map {|c| { :facet => c[0], :count => c[1], :a_facet => a_facet(field, c[0], c[1]) } } }
        }
        facets = facets.select {|f| f[:counts].uniq.size > 0 }
      end

      def result_text
        "#{totalResults} result#{ totalResults > 1 ? "s": ""}"
      end

      def opensearch
        feed(:opensearch)
      end

      def totalResults
        if opensearch.respond_to?(:key?) and opensearch.key?(:totalResults)
          opensearch[:totalResults]
        else
          0
        end
      end

      def qtime
        
      end

      def page
        1
      end
      def next
        page+1
      end

      def a_facet(field,facet,count)
        "<a href=\"#{base}&amp;fq=#{CGI.escape(field.to_s)}:#{CGI.escape(facet.to_s)}\">#{facet}</a>"
      end

      def add_filter(current_uri, filter)
      end   

      def feed(key=nil)
        if feed? key
          key.nil? ? @hash[:feed] : @hash[:feed][key]
        else
          []
        end
      end


      def feed?(key=nil)
        if key.nil?
          @hash.key? :feed
        else
          @hash.key? :feed and @hash[:feed].key? key
        end
      end



    end
  end
end