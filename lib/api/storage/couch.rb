require "#{File.dirname(__FILE__)}/../client"
require "#{File.dirname(__FILE__)}/../atom/feed"
require "patron"

module Api
  module Storage

    # http://wiki.apache.org/couchdb/HTTP_Document_API
    class Couch < Api::Client

      def initialize(config = {})
        @http = Patron::Session.new
        @http.headers["User-Agent"] = self.class.name
        @http.headers["Accept"] = "application/json"
        @http.headers["Content-Type"] = "application/json"

        @http.base_url = config["base_url"]
      end
      
      def get(id, headers={})
        super
      end
            
      def head(id, headers={})
        super
      end
        
      def put(id, data, headers={})
        
        status, headers, body = super
                
        # if successful create, return the saved document
        if 201 == status
          r = headers["Etag"].gsub(/["]/, "") # Get the revision number from the Etag header
          body = get(id, { :rev => r })[2] # Request content for the specific revision
          headers["Content-Length"] = body.bytesize.to_s # Set correct Content-Length
        end
        
        [status, headers, body]
      end
      
      def feed(params={}, headers={})

        response = @http.get("_all_docs?include_docs=true")
        result = JSON.parse(response.body)

        # use Api::Atom::Feed
        entries = result["rows"].map {|e|e["doc"]}

        # on save
        entries.each do | entry |
          entry["id"] = entry["_id"] # if not exists?
          entry.delete "_id"
          entry["link"] = { "href" => entry["code"], "rel" => "edit"} # if not exists?
        end
        
        data_header = Api::Atom::Feed.header
        data_header["opensearch:totalResults"] = entries.size
        
        feed = {}
        feed["header"] = data_header
        feed["entry"] = entries

        headers = response.headers
        headers["Content-Type"] = "application/json"
        headers["Content-Lenght"] = feed.to_json.bytesize.to_s
        
        [200, headers, feed.to_json]
        # 304 403 200
      end
      
      

    end
  end
end
