require "rack/client"

module Npolar
  module Storage
    class Couch

      JSON_ARRAY_REGEX = /^(\s+)?\[.*\](\s+)?$/
  
      HEADERS = {
        "Accept" => "application/json",
        "Content-Type" => "application/json; charset=utf-8",
        "User-Agent" => self.name }
  
      attr_accessor :client, :headers, :read, :write, :accepts, :formats
  
      def accepts
        @accepts ||= ["json"]
      end
  
      def initialize(read, write = nil)
        if read.respond_to? :key? and read.key? "read"
          if write.nil? and read.key? "write"
            write = read["write"]
          end
          read = read["read"]
        end
        @read = read.gsub(/[\/]$/, "")
        @write = write.nil? ? read : write
        @write = @write.gsub(/[\/]$/, "")
        @headers = HEADERS
      end
  
      def delete(id, params={})
        response =  writer.delete(id, headers, params)
        [response.status, response.headers, response.body]
      end
  
      def formats
        @formats ||= ["json"]
      end
  
      def get(id, params={})
        case id
        when "ids", "" then ids
        else
          response = reader.get(id, headers, params)
          [response.status, response.headers, response.body]
        end
        
      end
  
      def head(id, params={})
        response = reader.head(id, headers, params)
        [response.status, response.headers, response.body]
      end
  
      def headers
        @headers ||= HEADERS
      end
  
      def parsable?
        true
      end
  
      def post_many(data, params={})        
        if data !~ JSON_ARRAY_REGEX
          raise ArgumentException, "Please provide data as a JSON array string"
        end
  
        couch = { "docs" => JSON.parse(data) }
        data = couch.to_json
        response = writer.post("_bulk_docs", headers, data)        
        [202,  { } , ["POSTed #{couch['docs'].size} documents"]]
      end
  
      def post(data, params={})
  
        if data.is_a? Hash
          data = data.to_json
        end
  
        if data =~ JSON_ARRAY_REGEX
          post_many(data, params)
        else
          # params?
          response = writer.post("", headers, data)
          if 201 == response.status
            couch = JSON.parse(response.body)
            created = reader.get(couch["id"], {"rev" => couch["rev"] })
            response.body = created.body
          end
          [response.status, response.headers,response.body]
  
        end
  
      end
  
      # @param String id UUID or SHA1 hash, e.g. "69f3f072-27a0-4d25-a5bf-aac8f7e31d8f"
      # @param String data JSON
      # @param Hash params?
      def put(id, data, params={})
        # params?
        #if params.key? "attachment"
        # #couch.put("")
        #end
        response = writer.put(id, headers, data)
        if 201 == response.status
          rev = response.headers["Etag"].gsub(/["]/, "") # Get the revision number from the Etag header
          created = writer.get(id, {"rev" => rev }) # GET document back from writer 
          response.body = created.body
        end
        [response.status, response.headers,response.body]
      end
  
      protected
  
      def ids
        ids = []
        response = couch.get(read+"/_all_docs")
        
        if 200 == response.status
          ids = Yajl::Parser.parse(response.body)["rows"].map {|row| row["id"] }
          status = 200
        else
          status = 501
        end
        [status, {"Content-Type" => HEADERS["Content-Type"]}, [ Yajl::Encoder.encode(ids)+"\n"]] # Couch returns text/plain here!?
      end
  
      protected
  
      # Raw client
      def couch
        ::Rack::Client.new(@uri)
      end
  
      # Protected client
      def client(uri)
        @client ||= ::Rack::Client.new(uri) do
          # Security feature: Disallow blank ids, and ids starting with _
          # Blank ids plus DELETE means bam!, the second could leak special CouchDB documents
          use Npolar::Rack::ValidateId
          run ::Rack::Client::Handler::NetHTTP
        end
      end
  
      def reader
        client(read+"/")
      end
      
      def writer
        client(write+"/")
      end

    end
  end
end
# http://theschemeway.blogspot.no/2011/02/securing-couchdb-database.html
# SSL only write?
# http://blog.couchbase.com/what%E2%80%99s-new-couchdb-10-%E2%80%94-part-4-security%E2%80%99n-stuff-users-authentication-authorisation-and-permissions
# Authorization: AWS + KeyId + : + base64(hmac-sha1(VERB + CONTENT-MD5 + CONTENT-TYPE + DATE + …))
#http://dagi3d.net/
# http://dagi3d.net/posts/5-api-authentication