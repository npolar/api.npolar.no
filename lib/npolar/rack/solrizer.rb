# encoding: utf-8
module Npolar

  module Rack
    # https://github.com/npolar/api.npolar.no/blob/master/lib/npolar/rack/solrizer.rb
    # @todo Create SolrQuery class to replace :q lambda
    # @todo Create/use JSON Feed class?
    class Solrizer < Npolar::Rack::Middleware

      def self.query_or_save
        lambda {|request|
          if ["GET", "HEAD"].include? request.request_method and not request["q"].nil?
            true
          elsif ["POST","PUT", "DELETE"].include? request.request_method
            true
          else
            false
          end
        }
      end

      def self.searcher
        lambda {|request| ["GET", "HEAD"].include? request.request_method }
      end

      def self.uri=uri
        if uri.respond_to? :gsub
          uri = uri.gsub(/[\/]$/, "")
        end
        @@uri=uri
      end

      def self.uri
        @@uri ||= "http://localhost:8983/solr"
      end

      CONFIG = {
        :core => nil,
        :condition => self.query_or_save,
        :facets => nil,
        :model => nil,
        :select => nil,
        :q => lambda {|request|
          qstar = request["q"] ||= "*"

          if qstar =~ /^[\*]$|^\*\:\*$|^(\s+)?$/
            "*:*"
          else
  
            unless qstar =~ /\*/
              qstar = qstar.downcase+"*"
            end
            qstar = qstar.delete(":")
            "title:#{qstar} OR #{qstar}"
          end
          
          
        },
        :fq => [],
        :feed => lambda {|response|

          facets = {}

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

          pagesize = response["responseHeader"]["params"]["rows"].to_i
          start = response["response"]["start"]
          {"feed" => {
            # http://www.opensearch.org/Specifications/OpenSearch/1.1#OpenSearch_response_elements
            "opensearch" => {
              "totalResults" =>  response["response"]["numFound"].to_i,
              "itemsPerPage" => pagesize,
              "startIndex" => response["response"]["start"].to_i
            },
            "atom" => {
              "links" => [{"rel" => "next", "href" => start+pagesize, "type"=>"feed"}
              ]
            },

            "facets" => facets,
            "entries" => response["response"]["docs"]}}

        },
        :summary => lambda {|doc| doc["summary"]},
        :rows => 50,
        :wt => "ruby"
      }
      # q=title:foo OR exact:foo OR text:foo*


      def condition?(request)
        config[:condition].call(request)
      end

      # Only called if #condition? is true
      def handle(request)
        @request = request
        case request.request_method
          when "DELETE" then delete(request)
          when "POST", "PUT" then save(request)
          else search(request)
        end
      end

      def delete(request)
        log.debug self.class.name+"#delete"
        log.warn "Not implemented"
        @app.call(request.env)
      end

      def save(request)
        begin
          #log.debug self.class.name+"#save"
          #json = JSON.parse(request.body.read)
          #request.body.rewind
          #log.debug json.keys
          # [] => throw directly at Solr
          log.warn "Not implemented"
          @app.call(request.env)
        rescue RSolr::Error::Http => e
          [e.response[:status].to_i, {"Content-Type" => "text/html"}, [e.response[:body]]]
        ensure
          #@app.call(request.env)
        end
      end

      def search(request)
        begin
          start = params["start"] ||= 0
          rows  = params["limit"]  ||= config[:rows]
        
          fq_bbox = []
          if params["bbox"]
            w,s,e,n = bbox = params["bbox"].split(" ").map {|c|c.to_f}
            fq_bbox = ["north:[#{s} TO #{n}]", "east:[#{w} TO #{e}]"]
          end

          response = rsolr.get select, :params => {
            :q=>q, :start => start, :rows => rows,
            :fq => fq+fq_bbox,
            :facet => facets.nil? ? false : true,
            #:"facet.range" => ["north", "east", "south", "west", "updated"],
            #:"f.north.facet.range.start" => -90,
            #:"f.north.facet.range.end" => 90,
            #:"f.north.facet.range.gap" => 10,
            #:"f.east.facet.range.start" => -180,
            #:"f.east.facet.range.end" => 180,
            #:"f.east.facet.range.gap" => 20,
            #:"f.south.facet.range.start" => -90,
            #:"f.south.facet.range.end" => 90,
            #:"f.south.facet.range.gap" => 10,
            #:"f.west.facet.range.start" => -180,
            #:"f.west.facet.range.end" => 180,
            #:"f.west.facet.range.gap" => 20,
            #:"f.updated.facet.range.start" => "/NOW-100 YEARS/",
            #:"f.updated.facet.range.end" => "/NOW/",
            #:"f.updated.facet.range.gap" => 10,
            :"facet.field" => facets,
            #:"facet.mincount" => 1,
            #:"facet.limit" => -1,
            :fl => fl }

          if "solr" == request.format
            # noop
          else
            response = feed(response)
          end

          [200, {"Content-Type" => "application/json"}, [response.to_json]]
        rescue RSolr::Error::Http => e
          [e.response[:status].to_i, {"Content-Type" => "text/html"}, [e.response[:body]]]
        end
      end

      def to_solr
        model.to_solr
      end

      protected

      def feed(response)
        config[:feed].call(response)
      end

      def facets
        unless request["facets"].nil?
          if request["facets"] =~ /,/
            request_facets = request["facets"].split(",")
          else
            return false if /^false$/ =~ request["facets"]
            request_facets = [request["facets"]]
          end
        end
        
        # todo support facet.* `http://wiki.apache.org/solr/SimpleFacetParameters#facet.mincount
        # todo factes vs. multifacets
        if request_facets.respond_to? :"+="
          facets = request_facets += config[:facets]
        else
          facets = config[:facets]
        end
        
        unless facets.nil?
          facets = facets.uniq
          #facets = facets.map {|f|
          #  #"{!ex=multi_#{f}}#{f}"
          #  "#{f}"
          #}
        end
        facets

      end

      def fq
        if config[:fq].is_a? String
          config[:fq] = [config[:fq]]
        end
        fq = (request.multi("fq") + config[:fq]).uniq.map {|fq|

        if fq =~ /(.*):(.*)/
          k,v = fq.split(":")
          if v =~ /true|false/
            
            "#{k}:#{v}"
            
          elsif v =~ /^(∅|%E2%88%85|null|)$/ui
            "-#{k}:[\"\" TO *]"
          else
            "#{k}:\"#{CGI.unescape(v.gsub(/(%20|\+)/ui, " "))}\""
          end
        else
          fq
        end
      }



#.map {|k,v| [k, v.)]}
#qstar = CGI::unescape(qstar)
        # todo factes vs. multifacets
        #unless fq.nil?
        #  fq = fq.map {|q|
        #    k,v = q.split(":")
        #    #"{!tag=multi_#{k}}#{q}"
        #    "#{q}"
        #  }
        #end

      fq
      end

      def fl
        fl = request.params["fl"] ||= config[:fl]
      end

      def model
        @model ||= config[:model]
      end

      def model=model
        @model=model
      end

      def rsolr
        @rsolr ||= RSolr.connect :url => uri
      end

      def uri
        uri = config[:core] ||= ""
        if self.class.uri.is_a? String and self.class.uri =~ /^http(s)?:\/\// and uri !~ /^http(s)?:\/\//
          uri = self.class.uri.gsub(/[\/]$/, "") + "/#{uri}"
        end
        uri
      end

      def q
        config[:q].call(request)
      end

      def select
        select = config[:select] ||= "select"
        if  select =~ /^[\/]/
          select = select.gsub(/^[\/]/, "")
        end
        select
      end

      def self.summary(doc)
        config[:summary].call(doc)
      end


      def collection
        request.path_info.split("/")[1]
      end

      def workspace
        request.path_info.split("/")[0]
      end

      def wt
        config[:wt]
      end

    end
  end
end