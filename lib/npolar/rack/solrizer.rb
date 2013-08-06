# encoding: utf-8
module Npolar

  module Rack

    # Search and indexing middleware for Solr
    #
    # Search
    # On GET Solrizer returns a JSON feed, if a "q" parameter is given.
    # The JSON feed is created by a pluggable lambda function, so is the #q (Solr query) and #fq (Solr filter queries).

    # Indexing
    # On PUT, POST, and DELETE Solrizer can update the Solr search index, calling #to_solr on the incoming document
    #
    # Use
    #   use Npolar::Rack::Solrizer, { :core => "http://solr:8983/solr/collection1",
    #     :facets => ["concept", "ancestors", "children"] }
    # @todo
    # Remodule SolrQuery => Npolar::Rack::Solrizer::SolrQuery?

    # https://github.com/npolar/api.npolar.no/blob/master/lib/npolar/rack/solrizer.rb

    class Solrizer < Npolar::Rack::Middleware

      YEAR_REGEX = /^([-])?\d{4,}/
      DATE_REGEX = /(-)?(\d{4,})-(0[1-9]|1[0-2])-([12]\d|0[1-9]|3[01])/
      ISODATE_REGEX = /^#{DATE_REGEX}$/
      MONTH_REGEX = /^(-)?(\d{4,})\-(0[1-9]|1[0-2])$/
      DATETIME_REGEX = /T\d\d[:]\d\d[:]\d\dZ$/

      # Default condition lambda (see CONFIG)
      def self.query_or_save_json
        
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

      # Use this CONFIG condition lambda for a Search-only Solrizer
      def self.searcher
        lambda {|request| ["GET", "HEAD"].include? request.request_method }
      end

      # Set default Solr URI
      def self.uri=uri
        if uri.respond_to? :gsub
          uri = uri.gsub(/[\/]$/, "")
        end
        @@uri=uri
      end

      # Get default Solr URI
      def self.uri
        @@uri ||= "http://localhost:8983/solr"
      end

      # Middleware config
      CONFIG = {
        :core => nil,
        :condition => self.query_or_save_json,
        :facets => nil,
        :model => nil,
        :ranges => nil,
        :select => nil,
        :fl => Npolar::Api::SolrQuery.fields,
        :q => lambda {|request| Npolar::Api::SolrQuery.q(request)},
        :dates => Npolar::Api::SolrQuery.dates,
        :force => nil,
        :fq => lambda {|request|
          [] + request.params.select {|p|
            p =~ /^filter-.{1,}/}.select{|k,v| v =~ /.{1}/}.map {|k,v| "#{k.gsub(/^filter-/, "")}:#{v}"
          }
        },
        :feed => lambda { |response, request| Npolar::Api::SolrFeedWriter.feed(response, request)},
        :log => Npolar::Api.log,
        :summary => lambda {|doc| doc["summary"]},
        :rows => Npolar::Api::SolrQuery.rows,
        :wt => :ruby,
        :path => "/",
        :to_solr => lambda {|doc|doc},
      }
      # q=title:foo OR exact:foo OR text:foo*


      def condition?(request)
        # Only trigger on the mapped path
        if config[:path] !~ /#{request.path}/
          return false
        end 
        config[:condition].call(request)
      end

      def core
        @core ||= config[:core]
      end

      def core=core
        @core = core
      end

      def force
        config[:force] ||= {}
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
      # FIXME Upstream stuff to lambda or remove
      def handle_save(request)

        log.debug self.class.name+"#handle_save "+core
        t0 = Time.now

        begin

          # Save using upstream middleware (@app, if set) and grab the response
          if @app.nil?
            response = nil
          else

            log.debug "About to call @app"

            response = @app.call(request.env)
            
            # Return if upstream save fails
            unless [200, 201].include?(response.status)
              log.error "Upstream save failed with status #{response.status} before we could save to Solr"
              return [response.status, headers("json"), response.body]
            end
          end
          
          # Parse incoming JSON
          json = Yajl::Parser.parse(request.body.read, :symbolize_keys => true)
          request.body.rewind

          # Convert to Solr format and add (update index)
          # NOT ANYMORE: Notice we update Solr no matter if the upstream storage middleware succeeds or not

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

          log.debug "Solr response: #{solr_response[0.255]}"

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
            log.error "Failed saving to Solr (status #{status})"
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
      
      # Solr searchfl
      # Search request handler that returns a JSON feed (default) or CSV, Solr Ruby Hash, Solr XML
      # @return Rack-style HTTP triplet
      def handle_search(request)
        log.debug self.class.name+"#handle_search #{uri} #{solr_params}"
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

          if ["html", "json", "", nil].include? request.format
          status = response["responseHeader"]["status"]
          qtime = response["responseHeader"]["QTime"]
          hits = response["response"]["numFound"]
          log.debug "Solr hits=#{hits} status=#{status} qtime=#{qtime}"

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
          explanation = body
          if body =~ /<b>message<\/b>/ 
            explanation = body.split("<b>message</b>")[1]
          elsif body =~ /\'error\'\=\>\{\'msg\'/
            explanation = body.split("'error'=>{'msg'=>'")[1].split("',")[0]
          end

          error = { "error" => { "status" => status, "explanation" => "Solr request failed: #{explanation}"  } }
          [status, headers("json"), [error.to_json]]
      end

      # @return Array fq (filter queries)
      # FIXME draft=not(yes) is currently implemented like
      #   filter--draft=yes
      def fq

        # config[:fq] should contain a lambda that will extract fq from a request
        if config[:fq].respond_to?(:call)
          config_fq = config[:fq].call(request)
        elsif config[:fq].is_a? Array
          config_fq = config[:fq]
        else
          config_fq=[]
        end

        # Merge fq's in the request with filter-field= extracted above
        fq = (request.multi("fq") + config_fq + force.map {|k,v| "#{k}:#{v}" }).uniq.map {|fq|

          if fq =~ /(.*):(.*)/
            
            k,v = fq.split(":",2)

            
            if v =~ /true|false/
              
              "#{k}:#{v}"
              
            elsif v =~ /^(∅|%E2%88%85|null|)$/ui
              "-#{k}:[\"\" TO *]"
            elsif v =~ /(.*)?[.][.](.*)?/ or config[:dates].include? k
  
              # Trick all date queries into range query
              # This makes snazzy shortened year and date queries work for a single year or a single date
              if config[:dates].include? k           
                unless v =~ /(.*)?[.][.](.*)?/
                  v = "#{v}..#{v}"
                end 
              end
  
              from,to = v.split("..")
  
              if from.nil? or "" == from
                from = "*"
              end
              if to.nil? or "" == to
                to = "*"
              end

              # Switch from/to if from is greater than to
              if (from != "*" and to != "*" and from.respond_to?(:<) and to.respond_to?(:>))
                if from > to
                  from,to = to,from
                end
              end
              
              if config[:dates].include? k

                if from =~ DATETIME_REGEX or to =~ DATETIME_REGEX 
                  from = (from =~ YEAR_REGEX) ? from : "*"
                  to = (to =~ YEAR_REGEX) ? to : "*"
                elsif from =~ DATE_REGEX or to =~ DATE_REGEX
                  from,to = solr_date_range(from,to)
                  # At least one year (from or to)
                elsif from =~ MONTH_REGEX or to =~ MONTH_REGEX
                  from,to = solr_month_range(from,to)
                elsif from =~ YEAR_REGEX or to =~ YEAR_REGEX 
                  from,to = solr_year_range(from,to)
                end
  
                
              end 
              "#{k}:[#{from} TO #{to}]"
              # End of Date range

            else


              "#{k}:\"#{CGI.unescape(v.gsub(/(%20|\+)/ui, " "))}\""
            end
          else # fq does not contain :
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

      def solr_year_range(from,to)
        unless "*" == from
          from = DateTime.new(from[0..3].to_i, 1, 1).xmlschema.gsub(/\+00\:00$/, "Z")
        end

        unless "*" == to
          to = DateTime.new(to[0..3].to_i, 12, 31, 23, 59, 59).xmlschema.gsub(/\+00\:00$/, "Z")
        end
    
        [from,to]
      end

      def solr_date_range(from,to)
        # Get the years, or even *
        from_year,to_year=solr_year_range(from,to)
        if "*" == from_year
          from = "*"
        else
          from = DateTime.new(from_year.to_i, from[5..6].to_i, from[8..9].to_i).xmlschema.gsub(/\+00\:00$/, "Z")
        end
        if "*" == to_year
          to = "*"
        else

          to = DateTime.new(to_year.to_i, to[5..6].to_i, to[8..9].to_i, 23, 59, 59.999).xmlschema.gsub(/\+00\:00$/, "Z")
        end
        [from,to]
      end

      def solr_month_range(from,to)
        # Get the years, or even *
        from_year,to_year=solr_year_range(from,to)
        if "*" == from_year
          from = "*"
        else
          from = DateTime.new(from_year.to_i, from[5..6].to_i).xmlschema.gsub(/\+00\:00$/, "Z")
        end
        if "*" == to_year
          to = "*"
        else
          to = DateTime.new(to_year.to_i, to[5..6].to_i, -1, 23, 59, 59).xmlschema.gsub(/\+00\:00$/, "Z")
        end
        [from,to]
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
            :"facet.limit" => request["facet.limit"] ||= 100, # -1 == all
            :fl => fl,
            :wt => wt,
            :defType => "edismax",
            :sort => request["sort"] ||= nil,
            :"facet.sort" => request["facet.sort"] ||= "count",
            :qf => "text"

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


      # stats http://wiki.apache.org/solr/StatsComponent

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
