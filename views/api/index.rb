# encoding: utf-8 
module Views
  module Api  
    class Index < Npolar::Mustache::JsonView

      def initialize(app=nil)
        @app = app
        @hash = { "_id" => "api_index",
          #:workspaces => (Npolar::Api.workspaces - Npolar::Api.hidden_workspaces).map {|w| {:href => w, :title => w }},
          :form => {:placeholder => "Norwegian Polar Data API", :href => "", :id => "api",
          :source => '.json?q={query}&amp;callback={callback}',
          :"search-formats" => [
            #{:format=>"atom", :label =>"Atom"},
              {:format=>"csv", :label => "CSV"},
              {:format=>"html", :label => "HTML", :active => "active"},
              {:format=>"json", :label => "JSON", :active => ""},
            ]
          },
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
          :welcome_article => '',
          :data => { :workspaces => [] }
        }
        #merge ayyt
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
        @hash[:fields] = request["fields"]
        @hash[:sort] = request["sort"]

        @hash[:filters?] = false
        @hash[:filters] = []
        @hash[:collection_uri] = request.script_name
        if request["fq"]         
          @hash[:filters] = filters
          @hash[:filters?] = true
          
        end


        unless "html" == request.format
          feed = @app.call(env)
        else
          #html
          super # ie render
        end
      end

      # List of facet filters with link to remove
      def filters
        # For each filter we need a remove link, equal to current URI minus this filter
        request.multi("fq").map {|fq|
          # FIXME breaks on space, remove gsub with proper parameter shuffling
          # DIXE &fq= (empty => breaks)
          k,v = fq.split(":")
          unless k.nil? or v.nil? or k == "" or v == ""
            remove_href = base.gsub(/&fq=#{fq}/ui, "")
            {:filter => k, :value => CGI.unescape(v), :remove_href => remove_href }
          else
            nil
          end
        }.uniq
      end

      def filtered?(field, value)
        [] == filters.select {|f| f[:filter] == field.to_s and f[:value] == CGI.unescape(value) }
      end

      def formats
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
        
          formats = false
          link_relations = e.select {|k,v| k =~ /^link_/}.map {|k,v| { :rel => k.to_s.gsub(/^link_/, ""), :href => v } }
          if e.key? :title and e[:title].respond_to? :first
            e[:title] = e[:title].first
          end

          if e.key? :formats
            formats = e[:formats].map {|f| { :format => f, :label => f,
              :href => e.key?(:link_edit) ? "#{e[:link_edit]}.#{f}" : "" }
            }
          end

          e.merge(:"title?" => e.key?(:title), :json => e.to_json, :link_edit? => e.key?(:link_edit),
            :formats => formats, :link_relations => link_relations )
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
        facets = feed(:facets).map {|field,v|
          {:title => field, :counts => v.map {|c| { :facet => c[0], :count => c[1], :a_facet => link_facet(field, c[0], c[1]) } } }
        }
        facets = facets.select {|f| f[:counts].uniq.size > 0 }
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
      def link_facet(field, value, count)

        value = value == "" ? "∅" : value

        if  filtered?(field,value)
          if count > 0
            # FIXME 
            # Should remove start here to make sure that after paging you start from page one, but the following destroys base because fq is multi-paramter
            #base = facet_remove_href("start")
            "<a href=\"#{base}&amp;fq=#{CGI.escape(field.to_s)}:#{value.to_s == "" ? "∅" : CGI.escape(value.to_s)}\">#{value.to_s == "" ? "<code>∅</code>" : CGI.escapeHTML(value) }</a>"
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
        facet_href("start", previous)
      end



    end
  end
end