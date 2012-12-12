# encoding: utf-8
module Npolar

  module Rack
    
    # Solrizer returns a JSON feed on GET with a query ("q" parameter is present)
    # The #feed is created by a pluggable lambda function, so is the #q (Solr query) and #fq (Solr filter queries).
    # On PUT or POST Solrizer updates the Solr search index, calling #to_solr on the incoming document
    #
    # https://github.com/npolar/api.npolar.no/blob/master/lib/npolar/rack/solrizer.rb
    class Solrizer < Npolar::Rack::Middleware

      def self.query_or_save_json
        lambda {|request|
          if ["GET", "HEAD"].include? request.request_method and not request["q"].nil?
            true
          elsif ["POST","PUT", "DELETE"].include? request.request_method and "json" == request.format
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
        :condition => self.query_or_save_json,
        :facets => nil,
        :model => nil,
        :select => nil,
        :q => lambda {|request| Npolar::Api::SolrQuery.q(request)},
        :fq => [],
        :feed => lambda { |response, request| Npolar::Api::SolrFeedWriter.feed(response, request)},
        :log => Npolar::Api.log,
        :summary => lambda {|doc| doc["summary"]},
        :rows => 50,
        :wt => :ruby,
        :to_solr => lambda {|doc| doc },
      }
      # q=title:foo OR exact:foo OR text:foo*


      def condition?(request)
        config[:condition].call(request)
      end

      def core
        @core ||= config[:core]
      end

      def core=core
        @core = core
      end

      # Only called if #condition? is true
      def handle(request)
        @request = request
        log.debug self.class.name+"#handle(#{request}) #{request.request_method} #{request.url}"
        if request["q"] and "POST" == request.request_method
          # search
        end

        case request.request_method
          when "DELETE" then handle_delete(request)
          when "POST", "PUT" then handle_save(request)
          else handle_search(request)
        end
      end

      def handle_delete(request)
        log.debug self.class.name+"#delete"
        log.warn "NOT IMPLEMENTED: Solr delete"
        @app.call(request.env)
      end

      def rsolr
        @rsolr ||= RSolr.connect(:url => uri, :update_format => :json)
      end

      def rsolr=rsolr
        @rsolr=rsolr
      end

      # Save to Solr
      def handle_save(request)

        log.debug self.class.name+"#handle_save"

        begin

          # Save using upstream middleware (@app, if set) and grab the response
          if @app.nil?
            response = nil
          else
            response = @app.call(request.env)
          end
          
          # Parse incoming JSON
          json = JSON.parse(request.body.read, :symbolize_keys => true)
          request.body.rewind

          # Convert to Solr format and add (update index)
          # Notice we update Solr no matter if the upstream storage middleware succeeds or not
          solr = to_solr(json)
          solr_response = rsolr.add(solr)

          # Debug output
          #log.debug solr.to_json
          log.debug "Solr response: #{solr_response}"

          # Return upstream response if any, otherwise the Solr response
          if response.nil?
            solr_response
          else
            response
          end

        rescue RSolr::Error::Http => e
          log.debug self.class.name+"#save raised RSolr::Error::Http"
          json_error_from_exception(e)
        end
      end
      
      # Solr search
      # Search request handler that returns a JSON feed (default) or CSV, Solr Ruby Hash, Solr XML
      # @return Rack-style HTTP triplet
      def handle_search(request)
        log.debug self.class.name+"#handle_search"
        begin
          
        
          fq_bbox = []
          if params["bbox"]
            #w,s,e,n = bbox = params["bbox"].split(" ").map {|c|c.to_f}
            #fq_bbox = ["north:[#{s} TO #{n}]", "east:[#{w} TO #{e}]"]
          end
          
          response = search
          #log.debug "Solr response: #{response}"

          if ["html", "json", "", nil].include? request.format
            [200, headers("json"), [feed(response).to_json]]
          elsif ["solr"].include? request.format
            [200, headers("json"), [response.to_json]]
          elsif ["csv", "xml"].include? request.format
            #http://wiki.apache.org/solr/CSVResponseWriter
            [200, headers(request.format), [response]]
          end

          
        rescue RSolr::Error::Http => e
          log.debug self.class.name+"#handle_search raised RSolr::Error::Http"
          json_error_from_exception(e)
        end
      end

      # Performs search using rsolr
      # @return Hash
      def search(params=nil)
        rsolr.get select, :params => solr_params
      end

      # Converts incoming JSON (or other document) to Solr-style JSON Hash
      def to_solr(json)
        config[:to_solr].call(json)
      end

      # Solr core URI
      def uri
        if core =~ /^http(s)?:\/\//
          core
        elsif self.class.uri.is_a? String and self.class.uri =~ /^http(s)?:\/\// 
          self.class.uri.gsub(/[\/]$/, "") + "/#{core}"
        end
      end

      protected

      def feed(response)
        config[:feed].call(response, request)
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

      def json_error_from_exception(e)
          log.error e
          status = e.response[:status].to_i
          body = e.response[:body]
          explanation = ""
          if body =~ /<b>message<\/b>/ 
            explanation = body.split("<b>message</b>")[1]
          end
          #elsif explanation = body.split("'error'=>{'msg'=>")[1].split("',")[0]
          error = { "error" => { "status" => status, "explanation" => "Solr request failed: #{explanation}" , "response" => body } }
          [status, headers("json"), [error.to_json]]
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

      def log
        @log ||= config[:log]
      end

      def model
        @model ||= config[:model]
      end

      def model=model
        @model=model
      end

      def solr_params
        start = request["start"] ||= 0
        rows  = request["limit"]  ||= config[:rows]
        
        params = {
            :q=>q, :start => start, :rows => rows,
            :fq => fq,
            :facet => facets.nil? ? false : true,
            #:"facet.range" => ["north", "east", "south", "west"],
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
            :"facet.mincount" => request["facet.mincount"] ||= 1,
            :"facet.limit" => 500, #-1,
            :fl => fl,
            :wt => wt,

          }

        if request.format == "csv"
          params = params.merge({
            :"csv.separator" => "\t",
            :"csv.mv.separator" => "|",
            :"csv.encapsulator" => '"'
          })
        end
        params
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
        wt = case request.format
          when "json" then :ruby
          when "csv" then :csv
          when "xml" then :xml
          else config[:wt]
        end
      end

    end
  end
end