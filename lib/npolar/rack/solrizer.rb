# encoding: utf-8
require 'pp'

module Npolar

  module Rack
        
    # Solrizer: Search and indexing middleware for Solr
    #
    # Solrizer returns a JSON feed on GET with a query ("q" parameter is present)
    # The #feed is created by a pluggable lambda function, so is the #q (Solr query) and #fq (Solr filter queries).
    # On PUT or POST Solrizer updates the Solr search index, calling #to_solr on the incoming document
    #
    # https://github.com/npolar/api.npolar.no/blob/master/lib/npolar/rack/solrizer.rb
    class Solrizer < Npolar::Rack::Middleware

      def self.query_or_save_json
        
        lambda {|request|
          Npolar::Api.log.debug request.request_method
          Npolar::Api.log.debug request.format

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
        :to_solr => lambda {|doc|doc},
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
        log.debug __FILE__
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

        rsolr.delete_by_id request.id

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
        t0 = Time.now

        begin
          log.debug "@app: #{@app.class.name}"
          # Save using upstream middleware (@app, if set) and grab the response
          if @app.nil?
            response = nil
          else
            log.debug "About to call @app"
            response = @app.call(request.env)
            log.debug response.inspect

            # bail if db write fails
            if ![200, 201].include?(response.status)
              log.error error_hash response.status, "DB write failed before we could write to Solr"
            end
          end
          
          # Parse incoming JSON
          json = Yajl::Parser.parse(request.body.read, :symbolize_keys => true)
          request.body.rewind

          # Convert to Solr format and add (update index)
          # Notice we update Solr no matter if the upstream storage middleware succeeds or not

          # POST/no id => multiple documents
          if request.id? == false and "POST" == request.request_method and json.respond_to? :each
            solr = []
            # FIXME support Refine json
            # FIXME support Solr response JSON
            # json[:response][:docs].
          
            # parse reponse from couch, it might be useful to us...
            couch = Yajl::Parser.parse(response.body[0])

            # if couch responds with a populated list of ids, it has generated these for us,
            # so let's use them when we put records into solr 
            if couch.has_key?('response') and couch['response'].has_key?('ids') and !couch['response']['ids'].empty?
              provide_id = true
            end

            if json.is_a? Array
              json.each_with_index do |doc, index|
                if provide_id
                  doc['id'] = couch['response']['ids'][index]
                end
                solr << to_solr(doc)
              end
              size = solr.size
            else
              #Grab response from Couch (single post the response body will be the document)
              json = Yajl::Parser.parse(response.body.first, :symbolize_keys => true)
              
              solr = to_solr(json)
              size = 1
            end
            
            log.debug "About to POST #{size} Solr documents"
          else
            # PUT => single document
            solr = to_solr(json)
            size = 1
          end

          t1 = Time.now

          solr_response = rsolr.add(solr) # Hash

          elapsed = Time.now-t1

          log.debug "Solr response: #{solr_response}"

          log.debug "Total time: #{Time.now-t0} seconds"

          # Return upstream response if any, otherwise the Solr response
          if response.nil?
            status = case solr_response["responseHeader"]["status"]
              when 0 then 201
              else 503
            end          
          else
            status = response.status
          end

          if [200, 201].include?(status)
            log.info "#{request.request_method} #{request.url} #{status} saved #{size} Solr document(s) in #{elapsed} seconds (#{size/elapsed} qps)"
          else
            log.error "Failed saving to Solr"
            puts response.inspect
          end

          if response.nil?
            qtime = solr_response["responseHeader"]["QTime"]
            [status, headers("json") , [{"response" => { "status" => status,
              "summary" => "Updated #{size} Solr documents in #{elapsed} seconds"},
              "method" => request.request_method, "qps" => size/elapsed, "qtime" => qtime
          }.to_json+"\n"]]

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

          # if bulk=true in query, proceed
          if request["bulk"] and request["bulk"] == "true"

            # collect id's from search results
            ids = []
            response["response"]["docs"].each do |doc|
              ids << doc["id"]
            end

            log.debug("Bulk-query for ids: #{ids}")

            # prepare to POST ids to couch to bulk-fetch the actual documents
            post_env = request.env
            post_env["REQUEST_METHOD"] = "POST"
            post_env["rack.input"] = StringIO.new({ "keys" => ids }.to_json)
            post_env["CONTENT_TYPE"] = "application/json"

            # POST to couch and return
            resp = @app.call(post_env)
            return [200, headers("json"), resp.body]
          end

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
        fl = request.params["fields"] ||= config[:fl]
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
            :"facet.limit" => request["facet.limit"] ||= -1, # all
            :fl => fl,
            :wt => wt,
            :defType => "edismax",
            :sort => request["sort"] ||= nil,
            :"facet.sort" => "count"
            #:qf => "text"

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

      # Returns the Solr serch (select) handler (defeult is "select")
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
