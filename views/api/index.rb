# encoding: utf-8 
module Views
  module Api  
    class Index < Npolar::Mustache::JsonView

      # Coming APIs: Tracking, Monitoring, Placenames,Ecotox

      def initialize(app=nil, hash={})
        @app = app
        @hash = { "_id" => "api_index",
          #:workspaces => (Npolar::Api.workspaces - Npolar::Api.hidden_workspaces).map {|w| {:href => w, :title => w }},
          :form => {:placeholder => "Norwegian Polar Data API", :href => "", :id => "api",
          :source => '?q={query}&amp;callback={callback}&amp;format=json',
          :"search-formats" => [
            #{:format=>"atom", :label =>"Atom"},
              {:format=>"csv", :label => "CSV"},
              {:format=>"html", :label => "HTML", :active => "active"},
              {:format=>"json", :label => "JSON", :active => ""},
            ]
          },
          :limit => 25
          #:svc => { :search => [
          #  #{:title => "Biology", :href => "/biology/?q="},
          #  #{:title => "Ecotox", :href => "/ecotox/?q="},
          #  {:title => "Dataset", :href => "/dataset/?q=", :alt => "Norwegian Polar Institute's datasets (discovery level metadata"},
          #  {:title => "GCMD Concept", :href => "/gcmd/concept/?q="},
          #  #{:title => "Map", :href => "/map/archive?q="},
          #  
          #  #{:title => "Monitoring ", :href => "/monitoring/indicator?q="},
          #  #{:title => "Org", :href => "/org/?q="},
          #  #{:title => "Marine biology", :href => "/biology/marine/?q="},
          #  {:title => "Oceanography", :href => "/oceanography/?q="},
          #  #{:title => "Person", :href => "/person/?q="},
          #  #{:title => "Placename", :href => "/placename/?q="},
          #  #{:title => "Polar bear", :href => "/polar-bear/reference/?q="},
          #  {:title => "Project", :href => "/project/?q="},
          #  {:title => "Publication", :href => "/publication/?q="},
          #  #{:title => "Rapportserie", :href => "/rapportserie/105/?q="},
          #  #{:title => "Sighting", :href => "/sighting/fauna?q="}
          #  {:title => "Service", :href => "/api/?q="}
          #  #{:title => "Seaice"},
          #  #{:title => "Tracking"}
          #  ]},
          #:welcome_article => '<p>This service provides machine readable access to the <a href="http://npolar.no/en">Norwegian Polar Institute</a>\'s data.<br/> Humans should head over to <a href="http://data.npolar.no">Norwegian Polar Data</a>.</p>',
          #:data => { :workspaces => [] }
        }

        @hash = @hash.merge hash
      end

      def call(env)
        
        @hash[:request] = @request = Npolar::Rack::Request.new(env)
        
        @hash[:self] = request.url
        @hash[:base] =  request.url # CGI.escapeHTML => 

        @hash[:q] = request["q"]
        if request["q"] 
          @hash[:welcome_article] = nil
          @hash[:form][:placeholder] = request.script_name.split("/").map {|p| p.capitalize+" "}.join.gsub(/^\s+/, "")
          #@hash[:form][:source] = "&amp;format=json&amp;q={query}&amp;callback={callback}"
        end
        @hash[:bbox] = request["bbox"]
        @hash[:dtstart] = request["dtstart"]
        @hash[:dtend] = request["dtend"]
        @hash[:fields] = request["fields"] #Npolar::Api::SolrQuery.fields.join(", ")
        @hash[:sort] = request["sort"]

        @hash[:filters?] = false
        @hash[:filters] = []
        @hash[:collection_uri] = request.script_name
        if request["fq"]         
          @hash[:filters] = filters
          @hash[:filters?] = true
          
        end


        if "html" == request.format
          super # ie render
        else
          @app.call(env) # return feed  
        end
      end

      # List of facet filters with link to remove
      def filters
        # For each filter we need a remove link, equal to current URI minus this filter
        # 1. Solr-style filters (multi fq)
        filters = request.multi("fq").map {|fq|
          # FIXME breaks on space, remove gsub with proper parameter shuffling
          # FIXE &fq= (empty => breaks)
          k,v = fq.split(":")
          unless k.nil? or v.nil? or k == "" or v == ""
            remove_href = base.gsub(/&fq=#{fq}/ui, "")
            {:filter => k, :value => CGI.unescape(v), :remove_href => remove_href }
          else
            nil
          end
        }.uniq

        # filter-*
        filters += request.params.select {|k,v| k =~ /^filter\-/ }.map {|k,v|
            remove_href = base
            {:filter => k.gsub(/^filter\-/, ""), :value => CGI.unescape(v), :remove_href => remove_href }
          }
        filters
      end

      def filtered?(field, value)
        [] == filters.select {|f| f[:filter] == field.to_s and f[:value] == CGI.unescape(value) }
      end

      def formats
      end

      def frontpage?
        request.path == "/"
      end

      def search?
        request.path != "/"
      end

      def head_title
        "api.npolar.no"
      end
          
      def head_links
        #links = []
        #["atom"].each do |format|
        #  
        #  links << atom_link(base+facet_href("format", format), "Atom feed")
        #end
        #links.join("\n")
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
        feed(:entries).map {|e|
        
          if e.key? :title and e[:title].respond_to? :first
            e[:title] = e[:title].first
          end

          edit_links = (e.links||[]).select {|link| link.rel == "edit" }

          if edit_links.any?
            link_edit = edit_links[0].href
          else
            link_edit = e.id
          end

          e.merge(:"title?" => title?(e), :link_edit => link_edit, :json => e.to_json[0..255], :link_edit? => true )
        }
      end

      def self.dl(doc)
        dl = "<dl>"
        doc.each do |k,v|
          dl+= "<dt>#{CGI.escapeHTML(k.to_s)}</dt>"
          dl+= "<dd>#{CGI.escapeHTML(v.to_s)}</dd>"
        end
        dl += "</dl>"
        dl
      end

      def entries_size
        entries.size
      end

      def results?
        totalResults > 0
      end

      def facets
        if not feed.respond_to?(:facets)
          return []
        end
        
        if feed.facets.nil? or feed.facets.none?
          return []
        end
        
        # Solrizer?
        if feed.facets.first.is_a? Array          
          facets = (feed.facets||[]).map {|field,v|
            if v.respond_to?(:map)
              # v = Solrize style facet values [["Svalbard", 987], ["Dronning Maud Land", 123]]
              {:title => field, :counts => v.map {|c| { :facet => c[0], :count => c[1], :a_facet => link_facet(field, c[0], c[1]) } } }
            else
              return []
            end
          }
        else
          # Icelastic style [{"topics":[{"term":"glaciology","count":1,"uri":"..."},{"term":"ecology","count":1,"uri":"..."}]}]
          facets = feed.facets.map {|facet|
            field = facet.keys.first
            { title: field, counts: facet[field].map {|f|
              c = f.select {|k,v| k == "count" }.map {|c| c[1]}.first
              { facet: f.term, count: c, a_facet: "<a href=\"#{f.uri}\">#{f.term}</a>"}
              }
            }
          }
        end
        facets.select {|f| f[:counts].uniq.size > 0 }
      end

      def facet_href(facet, value)
        "?"+merge_params(facet, value).map{|k,v| "#{k}=#{v}"}.join("&")
      end

      def facet_remove_href(facet)
        request.params.delete(facet)
        "?"+request.params.map{|k,v| "#{k}=#{v}"}.join("&")
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


      def first
        feed(:list)[:first]
      end

      def first?
        if next_page == false and first < feed(:list)[:last]
          true
        else
          false
        end
      end
      
      def geojson_uri      
        "#{ self }&format=geojson&fields=measured,object,species,deployed,individual,platform,deployment,location,type,technology,latitude,longitude&filter-latitude=-90..90&group=deployment"
      end
    
      def title?(entry)
        return false if request["title"] =~ /^(false|no)$/
        entry.key?(:title)
      end

      def first_href
        facet_href("start", first)
      end

      def first_to_last
        unless entries.size <= 1
          "#{start+1}-#{start+entries.size}"
        end
      end

      def result_text
        "#{totalResults} result#{ totalResults > 1 ? "s": ""} in #{qtime/1000} seconds"
      end

      def map?
        request.params.key? "map"
      end

      def opensearch(key=nil)
        if key.nil?
          feed(:opensearch)
        elsif feed(:opensearch).key? key
          feed(:opensearch)[key]
        end
      end

    def ranges?
      ranges.size > 0
    end

    def ranges
      []
      #ranges = feed(:facets).map {|field,v|
      #  {:title => field, :stats => v.to_json }
      #}

      #ranges = facets.select {|f| f[:counts].uniq.size > 0 }
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
        nxt = self.send(:next)
        if nxt =~ /^\d+$  /
          facet_href("start", nxt)
        else
          nxt
        end
      end

      # Link to facet (if not already in a filtered)
      def link_facet(field, value, count)

        value = value == "" ? "∅" : value

        if  filtered?(field,value)
          if count > 0
            # FIXME 
            # Should remove start here to make sure that after paging you start from page one, but the following destroys base because fq is multi-paramter
            #base = facet_remove_href("start")
            "<a href=\"#{base}&amp;filter-#{CGI.escape(field.to_s)}=#{value.to_s == "" ? "∅" : CGI.escape(value.to_s)}\">#{value.to_s == "" ? "<code>∅</code>" : CGI.escapeHTML(value) }</a>"
          else
            # No clickable facet links for 0 counts
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
        if previous =~ /^\d+$/
          facet_href("start", previous)
        else
          previous
        end
      end



    end
  end
end