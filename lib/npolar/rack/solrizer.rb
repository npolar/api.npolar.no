module Npolar

  module Rack
    # https://github.com/npolar/api.npolar.no/blob/master/lib/npolar/rack/solrizer.rb
    # @todo Create SolrQuery class to replace :q lambda
    # @todo Create/use JSON Feed class?
    class Solrizer < Npolar::Rack::Middleware

      def self.query_or_save
        lambda {|request|
          if ["GET", "HEAD"].include? request.request_method and not request.params["q"].nil? and request.params["q"].size > 0
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
        :model => nil,
        :select => nil,
        :q => lambda {|request|
          qstar = request.params["q"] ||= "*"
          if qstar =~ /^[\*]$|^\*\:\*$/
            "*:*"
          else
  
            unless qstar =~ /\*/
              qstar = qstar+"*"
            end
            qstar = qstar.delete(":")
            "title:#{qstar} OR #{qstar}"
          end
          
        },
        :fq => [],
        :feed => lambda {|response|

          facets = response.key?("facet_counts") ? response["facet_counts"]["facet_fields"] : []

          {"feed" => { "facets" => facets, "entries" => response["response"]["docs"].select {|doc|
            doc.key? "title" and doc.key? "id"
          }}}
        },
        :summary => lambda {|doc| doc["summary"]},
        :rows => 10,
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
          rows  = params["rows"]  ||= config[:rows]
          response = rsolr.get select, :params => {
            :q=>q, :start => start, :rows => rows,
            :fq => fq,
            :facet => request.multi("facets").size > 0,
            :"facet.field" => facets,
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
        facets = request.params["facets"]
        if facets =~ /,/
          facets = facets.split(",")
        end
        facets
      end

      def fq
        if config[:fq].is_a? String
          config[:fq] = [config[:fq]]
        end
        fq = (request.multi("fq") + config[:fq]).uniq
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