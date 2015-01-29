# encoding: utf-8
require "time"
module Npolar

  module Rack

    # Solr search middleware
    #
    # Given a search (q=) Solrizer returns OpenSearch-like JSON feeds.
    #
    # Solrizer's behavior is highly pluggable through lambda functions, see config parameters
    # :feed, :q, and :fq below.
    #
    # Usage in Rack config.ru:
    #
    # use Npolar::Rack::Solrizer, { core: "http://localhost:8983/solr/tracking",
    #   facets => ["list", "of", "field", "facets"],
    #   "dates": ["positioned", "measured", "updated", "created", "edited"],
    #   "range_facets": [
    #    {
    #        "field": "measured",
    #        "gap": "+1YEAR",
    #        "start": "NOW/YEAR-100YEARS",
    #        "end": "NOW"
    #    },
    #    {
    #        "field": "latitude",
    #        "gap": 10,
    #        "start": -90,
    #        "end": 90
    #    },
    #    {
    #        "field": "longitude",
    #        "gap": 20,
    #        "start": -180,
    #        "end": 180
    #    },
    #    {
    #        "field": "altitude",
    #        "gap": 1000,
    #        "start": -1000,
    #        "end": 9000
    #    }
    #   ]
    # }
    #
    # https://github.com/npolar/api.npolar.no/blob/master/lib/npolar/rack/solrizer.rb

    class Solrizer < Npolar::Rack::Middleware

      YEAR_REGEX = /^([-])?\d{4,}/
      DATE_REGEX = /(-)?(\d{4,})-(0[1-9]|1[0-2])-([12]\d|0[1-9]|3[01])/
      ISODATE_REGEX = /^#{DATE_REGEX}$/
      MONTH_REGEX = /^(-)?(\d{4,})\-(0[1-9]|1[0-2])$/
      DATETIME_REGEX = /T\d\d[:]\d\d[:]\d\dZ$/
      INTEGER_REGEX = /^[-+]?[0-9]+$/
      FLOAT_REGEX = /^[-+]?[0-9\.]+$/ # may hit x.y.z

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
        lambda {|request| ["GET", "HEAD", "DELETE"].include? request.request_method }
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
        :condition => self.searcher,
        :facets => nil,
        :group => nil,
        :geojson => nil,
        :model => nil,
        :range_facets => nil,
        :select => nil,
        :fl => Npolar::Api::SolrQuery.fields,
        :q => lambda {|request| Npolar::Api::SolrQuery.q(request)}, # # q=title:foo OR exact:foo OR text:foo*
        :dates => Npolar::Api::SolrQuery.dates,
        :force => nil,
        :fq => lambda {|request|
          [] + request.params.select {|p|
            p =~ /^filter-.{1,}/}.select{|k,v| v =~ /.{1}/}.map {|k,v| "#{k.gsub(/^filter-/, "")}:#{v}"
          }
        },
        :feed => lambda { |response, request| Npolar::Api::SolrFeedWriter.feed(response, request)},
        :log => Npolar::Api.log,
        :save => lambda {|request| raise "Not implemented" },
        :summary => lambda {|doc| doc["summary"]},
        :rows => Npolar::Api::SolrQuery.rows,
        :wt => :ruby,
        :path => "/",
        :to_solr => lambda {|doc|doc},
      }
      
      def condition?(request)
        # Only trigger on the mapped path
        if config[:path].gsub(/\/$/, "") !~ Regexp.new(Regexp.quote(request.path.gsub(/\/$/, "")))
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

      def handle(request)
        
        @request = request
        log.info "#{request.request_method} #{request.path} [#{self.class.name}]"
        
        if request["q"] and "POST" == request.request_method
          return handle_search(request)
        end
        case request.request_method
          when "DELETE" then handle_delete(request)
          when "POST", "PUT" then handle_save(request)
          else handle_search(request)
        end
      end

      def handle_delete(request)
        log.debug self.class.name+" DELETE #{request.id}"

        rsolr.delete_by_id request.id

        @app.call(request.env)
      end

      def rsolr
        @rsolr ||= RSolr.connect(:url => uri, :update_format => :json)
      end

      def rsolr=rsolr
        @rsolr=rsolr
      end

      # Save to Solr index
      def handle_save(request)
        
        begin
          t0 = Time.now
          
          response = config[:save].call(request)
          
          elapsed = Time.now-t0

          log.debug "Solr indexing time: #{elapsed} seconds"

          response
          
        rescue => e

          json_error_from_exception(e)
        end
      end
      
      # Solr search
      # Search request handler that returns a JSON feed (default) or CSV, Solr Ruby Hash, Solr XML
      # @return Rack-style HTTP triplet
      def handle_search(request)
        log.debug self.class.name+"#handle_search #{uri} #{solr_params}"
        begin
          
          #fq_bbox = []
          #if params["bbox"]
          #  #w,s,e,n = bbox = params["bbox"].split(" ").map {|c|c.to_f}
          #  #fq_bbox = ["north:[#{s} TO #{n}]", "east:[#{w} TO #{e}]"]
          #end

          response = search

          # if bulk=true in query, proceed
          if request["bulk"] and request["bulk"] == "true"

            # collect id's from search results
            ids = []
            response["response"]["docs"].each do |doc|
              ids << doc["id"]
            end

            log.debug("Bulk-query for ids: #{ids}")

            # prepare to POST ids to upstream storage to bulk-fetch the actual documents
            post_env = request.env
            post_env["REQUEST_METHOD"] = "POST"
            post_env["rack.input"] = StringIO.new({ "keys" => ids }.to_json)
            post_env["CONTENT_TYPE"] = "application/json"

            # POST to upstream storage and return
            resp = @app.call(post_env)
            return [200, headers("json"), resp.body]
          end
          
          if ("geojson" == request.format) or ("json" == request.format and request["variant"]=~ /^geo(\+)?(json)?$/)
            [200, headers("geojson"), [geojson(response).to_json]]
          elsif ["solr"].include? request.format
            [200, headers("json"), [response.to_json]]
          elsif ["csv", "xml"].include? request.format
            #http://wiki.apache.org/solr/CSVResponseWriter
            [200, headers(request.format), [response]]
          elsif ("array" == request.format) or ("json" == request.format and request["variant"]== "array")
            [200, headers("json"), [response["response"]["docs"].to_json]]
          else
            
            #["html", "json", "", nil].include? request.format
            status = response["responseHeader"]["status"]
            qtime = response["responseHeader"]["QTime"]
            hits = response["response"]["numFound"]
            log.debug "Solr hits=#{hits} status=#{status} qtime=#{qtime}"

            [200, headers("json"), [feed(response).to_json]]
          end

        rescue ::RSolr::Error::Http => e
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
      def to_solr(body)
        config[:to_solr].call(body)
      end

      # Solr core URI
      def uri
        if core =~ /^http(s)?:\/\//
          core.gsub(/[\/]$/, "")
        elsif self.class.uri.is_a? String and self.class.uri =~ /^http(s)?:\/\// 
          self.class.uri.gsub(/[\/]$/, "") + "/#{core}"
        end
      end

      protected

      def feed(response)
        config[:feed].call(response, request)
      end
      
      def geojson(response)
        if request["geometry"]
          geometry = request["geometry"]
        else
          geometry = config[:geojson][:geometry]||="Point"
        end
        latitude = config[:geojson][:latitude]||"latitude"
        longitude = config[:geojson][:longitude]||"longitude"
        Npolar::Api::SolrFeedWriter.geojson_feature_collection(response, request, latitude,longitude, geometry)
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
        
        # todo facets vs. multifacets
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
      
      # Group (by field)
      def group_params
        gp = { :group => true,
          :"group.field" => request["group"],
          :"group.facet" => true,
          :"group.main" => true,
          :"group.limit" => request["group.limit"]||1,
          :"rows" => request["rows"]||-1,
          :"group.sort" => request["group.sort"]
        }
        if config[:group] != []
          if not config[:group].nil? and not config[:group][:sort].nil?
            gp[:"group.sort"] =  config[:search][:group][:sort]
          end
        end
        gp
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
      # @todo not(x)
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
              
              # Lucene needs the smallest number/date first in a range, so we convert these from string
              if from =~ INTEGER_REGEX and to =~ INTEGER_REGEX
                from = from.to_i
                to = to.to_i
              end
              if from =~ FLOAT_REGEX and to =~ FLOAT_REGEX
                from = from.to_f
                to = to.to_f
              end
              
              if (from != "*" and to != "*" and from.respond_to?(:<) and to.respond_to?(:>))
               
                if from > to
                  from,to = to,from
                end
              end
              from = from.to_s
              to = to.to_s
              
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
        # todo facets multifacets
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
          from = DateTime.new(from[0..3].to_i, 1, 1).to_time.utc.iso8601
        end

        unless "*" == to
          to = DateTime.new(to[0..3].to_i, 12, 31, 23, 59, 59.999999).to_time.utc.iso8601(6)
        end
    
        [from,to]
      end

      def solr_date_range(from,to)
        # Get the years, or even *
        from_year,to_year=solr_year_range(from,to)
        if "*" == from_year
          from = "*"
        else
          from = DateTime.new(from_year.to_i, from[5..6].to_i, from[8..9].to_i).to_time.utc.iso8601
        end
        if "*" == to_year
          to = "*"
        else

          to = DateTime.new(to_year.to_i, to[5..6].to_i, to[8..9].to_i, 23, 59, 59.999999).to_time.utc.iso8601(6)
        end
        [from,to]
      end

      def solr_month_range(from,to)
        # Get the years, or even *
        from_year,to_year=solr_year_range(from,to)
        if "*" == from_year
          from = "*"
        else
          from = DateTime.new(from_year.to_i, from[5..6].to_i).to_time.utc.iso8601
        end
        if "*" == to_year
          to = "*"
        else
          to = DateTime.new(to_year.to_i, to[5..6].to_i, -1, 23, 59, 59.999999).to_time.utc.iso8601(6)
        end
        [from,to]
      end

      def solr_params
        start = request["start"] ||= 0
        rows  = request["limit"]  ||= config[:rows]
        # Merge with user provided parameters, except some that shouldn't be repeated or has a different external meaning (group is a field in the API and bool in Solr)
        params = request.params.reject {|k,v| k =~ /limit|fields|start|group|facet\.sort|facet\.mincount|filter-/ }.merge ({
            :q=>q, :start => start, :rows => rows,
            :fq => fq,
            :facet => facets.nil? ? false : true,
            :"facet.field" => facets,
            :"facet.mincount" => request["facet.mincount"] ||= 1,
            :"facet.limit" => request["facet.limit"] ||= 100, # -1 == all
            :fl => fl,
            :wt => wt,
            :defType => "edismax",
            :sort => request["sort"] ||= nil,
            :"facet.sort" => request["facet.sort"] ||= "count",
            :qf => "text"
          })
        
        params = params.merge(range_facets)
        
        if request.format == "csv"
          params = params.merge({
            :"csv.separator" => "\t",
            :"csv.mv.separator" => "|",
            :"csv.encapsulator" => '"'
          })
        end
        
        if request["group"] =~ /\w+/
          params = params.merge(group_params)
        end
      
        
        params
      end
      
      def q
        config[:q].call(request)
      end
      
      def range_facets
        if config[:range_facets].nil?
          return {}
        end
        
        facet_range = config[:range_facets].map {|rf|
          if rf.field =~ /^[{][!]}(.)$/
            rf.field.split("}")[1]
          else
            rf.field
          end
        }
        rp = {}
        
        config[:range_facets].each { |rf|
          field = (rf.field =~ /^[{][!]}(.)$/) ? rf.field.split("}")[1] : rf.field
  
          rp.merge!({:"f.#{field}.facet.range.start" => rf.start,
            :"f.#{field}.facet.range.end" => rf.end,
            :"f.#{field}.facet.range.gap" => rf.gap })
        }
        rp[:"facet.range"] = facet_range        
        rp
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
