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
          :formats => [{:format=>"atom", :label =>"Atom"},
            {:format=>"csv", :label => "CSV"},
            {:format=>"json", :label => "JSON", :active => "active"},
          ],
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

  <p>The default response is a <a href="http://json.org">JSON</a> feed object.
In web browsers or other clients that send <code>Accept: text/html</code>, results are rendered in a data browser with powerful facet filtering (drill-down).
</p>

  <p>The search API follows the <a href="http://www.opensearch.org/">OpenSearch</a> specification.</p>
  
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

        @hash[:request] = @request = Npolar::Rack::Request.new(env)
        @hash[:self] = request.url
        @hash[:base] = request.url # CGI.escapeHTML => 

        @hash[:q] = request["q"]
        if request["q"] 
          @hash[:welcome_article] = nil
          @hash[:form][:placeholder] = request.script_name.split("/").map {|p| p.capitalize+" "}.join.gsub(/^\s+/, "")
        end
        @hash[:bbox] = request["bbox"]
        @hash[:dtstart] = request["dtstart"]
        @hash[:dtend] = request["dtend"]

        @hash[:filters?] = false
        if request["fq"]         
          @hash[:filters] = filters
          @hash[:filters?] = true
          @hash[:collection_uri] = request.script_name
        end

        unless "html" == request.format
          feed = @app.call(env)
        else
          super # ie render
        end
      end

      def filters
        request.multi("fq").map {|fq|
          k,v = fq.split(":")
          remove_href = base.gsub(/&fq=#{fq}/ui, "")
          {:filter => k, :value => CGI.unescape(v), :remove_href => remove_href }
        }.uniq
      end

      def filtered?(field, value)
        [] == filters.select {|f| f[:filter] == field.to_s and f[:value] == CGI.unescape(value) }
      end

      def head_title
        "api.npolar.no"
      end
          
      def head_links
        links = []
        ["atom"].each do |format|
          
          links << atom_link(base+facet_href("format", format), "Atom feed")
        end
        links.join("\n")
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

      def atom_link(href, title="", rel="alternate", type="application/atom+xml")
        href = CGI.escapeHTML(href)
        rel = CGI.escapeHTML(rel)
        title = CGI.escapeHTML(title)
        type = CGI.escapeHTML(type)
        "<link href=\"#{href}\" title=\"#{title}\" rel=\"#{rel}\" type=\"#{type}\" />"
      end

      def entries
        feed(:entries).map {|e| {:title => e[:title]||e[:title_ss], :id => e[:id], :json => e.to_json , :collection => e[:collection] } }
      end

      def entries_size
        entries.size
      end

      def results?
        totalResults > 0
      end

      def facets
        facets = feed(:facets).map {|field,v|
          {:title => field, :counts => v.map {|c| { :facet => c[0], :count => c[1], :a_facet => html_a_facet(field, c[0], c[1]) } } }
        }
        facets = facets.select {|f| f[:counts].uniq.size > 0 }
      end

      def facet_href(facet, value)
        "?"+merge_params(facet, value).map{|k,v| "#{k}=#{v}"}.join("&")
      end

      def facet_remove_href(facet)

         "?"+request.params.map{|k,v| "#{k}=#{v}"}.join("&")
      end

      def first
        feed(:list)[:first]
      end

      def first_href
        facet_href("start", first)
      end

      def first_to_last
        "#{start+1} to #{start+entries.size}"
      end

      def result_text
        "#{totalResults} result#{ totalResults > 1 ? "s": ""} in #{qtime/1000} seconds"
      end

      def opensearch(key=nil)
        if key.nil?
          feed(:opensearch)
        elsif feed(:opensearch).key? key
          feed(:opensearch)[key]
        end
      end

      def start
        opensearch(:startIndex)
      end
      alias :startIndex :start

      def totalResults
        if opensearch.respond_to?(:key?) and opensearch.key?(:totalResults)
          opensearch[:totalResults]
        else
          0
        end
      end

      def qtime
        feed(:search)[:qtime].to_f
      end

      def next
        feed(:list)[:next]
      end
      alias :next_page :next


      def next?
        false != next_page
      end

      def next_href
        facet_href("start", self.send(:next))
      end

      # Link to facet (if not already in a filtered)
      def html_a_facet(field, value, count)

        value = value == "" ? "∅" : value

        if filtered?(field,value)
          if count > 0
            "<a href=\"#{base}&amp;fq=#{CGI.escape(field.to_s)}:#{value.to_s == "" ? "∅" : CGI.escape(value.to_s)}\">#{value.to_s == "" ? "<code>∅</code>" : CGI.escapeHTML(value) }</a>"
          else
            "#{value}"
          end
        else
          "<strong>#{value}</strong>"
        end
      end

      def merge_params(param, value)
        request.params.merge({param => CGI::escape(value.to_s)})
      end

      def previous?
        false != previous
      end

      def previous
        feed(:list)[:previous]
      end

     def previous_href
        facet_href("start", previous)
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