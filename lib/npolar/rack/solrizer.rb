module Npolar

  module Rack
    # https://github.com/npolar/api.npolar.no/blob/master/lib/npolar/rack/solrizer.rb
    # @todo Create SolrQuery class to replace :q lambda
    class Solrizer < Npolar::Rack::Middleware

      CONFIG = {
        :core => nil,
        :model => nil,
        :select => "select",
        :q => lambda {|request|
          qstar = request.params["q"].delete(":")+"*"
          "title:#{qstar} OR #{qstar}"
        },
        :feed => lambda {|response|
          {"feed" => { "entries" => response["response"]["docs"].select{|doc|
            doc.key? "title" and doc.key? "workspace" and doc.key? "collection"
          }.map {|doc|
            { "title" => doc["title"], "workspace" => doc["workspace"], "collection" => doc["collection"],
              "summary" => doc["text"], "updated" => doc["updated"], "id" => doc["id"], "self" => doc["link"] } } }
          }
        },
        :rows => 10
      }
      # q=title:foo OR exact:foo OR text:foo*

      def condition? request
        if ["GET", "HEAD"].include? request.request_method and not request.params["q"].nil? and request.params["q"].size > 0
          true
        elsif ["POST","PUT", "DELETE"].include? request.request_method and request.id?
          true
        else
          false
        end
      end

      # Only called if #condition? is true
      def handle(request)
        case request.request_method
          when "DELETE" then delete(request)
          when "POST", "PUT" then save(request)
          else search(request)
        end
      end

      def delete(request)
        raise "Not implemented"
      end

      def save(request)
        # no model no_to solr => to text and id, +text?
        raise "Not implemented"
      end

      def search(request)
        begin
          start = params["start"] ||= 0
          rows  = params["rows"]  ||= config[:rows]
          fq = params["fq"]
          response = rsolr.get config[:select], :params => { :q=>q, :start => start, :rows => rows, :fq => fq }

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
            #jfeed = Atom::JsonFeed.new
            #jfeed.entries = response["response"]["docs"]
        config[:feed].call(response)
      end

      def q
        config[:q].call(request)
      end

      def model
        @model ||= config[:model]
      end

      def model=model
        @model=model
      end

      def rsolr
        @rsolr ||= RSolr.connect :url => config[:core]
      end

    end
  end
end