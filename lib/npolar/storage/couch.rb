require "rack/client"

module Npolar
  module Storage
    class Couch

      JSON_ARRAY_REGEX = /^(\s+)?\[.*\](\s+)?$/

      LIMIT = 1000
  
      HEADERS = {
        "Accept" => "application/json",
        #Accept-Encoding? 
        "Content-Type" => "application/json; charset=utf-8",
        "User-Agent" => self.name }

      attr_accessor :client, :headers, :read, :write, :accepts, :formats, :model, :limit
  
      def self.uri=uri
        if uri.respond_to? :gsub
          uri = uri.gsub(/[\/]$/, "")
        end
        @@uri=uri
      end

      def self.uri
        @@uri ||= URI  #"http://localhost:5984"
      end

      def accepts
        @accepts ||= ["json"]
      end
  
      def initialize(read, write = nil, config = {})
        if read.respond_to? :key? and read.key? "read"
          if write.nil? and read.key? "write"
            write = read["write"]
          end
          read = read["read"]
        end
        @read = read.gsub(/[\/]$/, "")
        @write = write.nil? ? read : write
        @write = @write.gsub(/[\/]$/, "")
      
        if @read !~ /^http(s)?:\/\// and self.class.uri =~ /^http(s)?:\/\//
          @read = self.class.uri+"/"+@read
        end

        if @write !~ /^http(s)?:\/\// and self.class.uri =~ /^http(s)?:\/\//
          @write = self.class.uri+"/"+@write
        end
        @headers = HEADERS

        if config.key? :limit and config[:limit].to_i > 0
          @limit = config[:limit]
        end

      end
  
      def delete(id, params={})
        response =  writer.delete(id, headers, params)
        [response.status, response.headers, response.body]
      end
  
      def formats
        @formats ||= ["json"]
      end
  
      def get(id, params={})
        if params["limit"].to_i > 0
          @limit = params["limit"].to_i
        end

        case id
          when "_meta" then meta
          when "_ids", "" then ids
          when "_feed" then feed(params)
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


  
      def post_many(data, params={})        
        if data !~ JSON_ARRAY_REGEX
          raise ArgumentException, "Please provide ata as JSON Array"
        end
  
        couch = { "docs" => Yajl::Parser.parse(data).map {|r|
          if r.key? "id" and not r.key "_id"?
            r["_id"] = r["id"]
          end

        } }
        # set _id from id
        data = couch.to_json
        response = writer.post("_bulk_docs", headers, data)
        [202,  {"Content-Type" => HEADERS["Content-Type"]} , ["POSTed #{couch['docs'].size} documents\n"]]
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
      # @param String|Hash data JSON data
      # @param Hash params
      def put(id, data, params={})

        if data.is_a? Hash
          data = data.to_json
        end


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

      def meta
        ids = []
        response = couch.get(read)
       
        if 200 == response.status
          ids = Yajl::Parser.parse(response.body)
          status = 200
        else
          status = 501
        end
        [status, {"Content-Type" => HEADERS["Content-Type"]}, [ Yajl::Encoder.encode(ids)+"\n"]] # Couch returns text/plain here!?
      end
  
      #           feed = feed.select { |row| row[:_id] !~ /_design/ }
      def ids
        ids = []

        response = couch.get(all_docs_uri(false))
        
        if 200 == response.status
          ids = Yajl::Parser.parse(response.body)["rows"].map {|row| row["id"] }
          status = 200
        else
          status = 501
        end
        [status, {"Content-Type" => HEADERS["Content-Type"]}, [ Yajl::Encoder.encode(ids)+"\n"]] # Couch returns text/plain here!?
      end

      def feed(params={})
        response = couch.get(all_docs_uri(true))

        if 200 == response.status

          feed = Yajl::Parser.parse(response.body, :symbolize_keys => true)[:rows].map { |row| row[:doc] }

          unless params["fields"].nil?
            if "*" == params["fields"]
              # no op
            else
              fields = params["fields"].split(",").map {|f|f.to_sym}
              feed = feed.map {|doc|
                doc = doc.select {|k,v| fields.include? k or fields.include? :* }
              
              }
              feed
            end
          else
            feed = Yajl::Parser.parse(response.body, :symbolize_keys => true)[:rows].map { |row|
              { :title => row[:doc][:title], :id => row[:doc][:id], :_id => row[:doc][:_id], :updated => row[:doc][:updated] }
            }
          end
          feed = feed.select { |row| row[:_id] !~ /_design/ }
          status = 200

        else
          feed = { "error" => { "status" => response.status, "explanation" => "Storage error #{response.status}" } }
          status = response.status
        end
        [status, {"Content-Type" => HEADERS["Content-Type"]}, [ Yajl::Encoder.encode(feed)+"\n"]] # Couch returns text/plain here!?
      end

      def all_docs_uri(include_docs=false)
        include_docs = (false == include_docs) ? "false" : "true" 
        # Use a view, if it exists
        # /#{read}/_design/feed/_view/fields?keys=["id","title","updated"]

        # Otherwise, fallback to _all_docs
        uri = "#{read}/_all_docs?include_docs=#{true}&limit=#{limit}" #&startkey=%22#{sk}%22&endkey=%22#{ek}%22"
      end

      def fetch(id,key=nil)

        begin
    
          status, headers, jsonstring = get(id)
    
          if 200 == status
            y = Yajl::Parser.new(:symbolize_keys => true)
            hash = y.parse(jsonstring)
            if key.nil?
              hash
            elsif hash.key? key.to_sym
              hash[key = key.to_sym]
            else
              nil
            end
          else
            raise Exception, "#{self.class.name}#fetch status: #{status}"
          end
        end
      end

      protected
  
      # Raw couch client, use to get _documents (@see #ids)
      def couch
        ::Rack::Client.new(@uri)
      end
  
      # Protected couch client
      def client(uri)
        @client ||= ::Rack::Client.new(uri) do
          # Security feature: Disallow blank ids, and ids starting with _
          # Blank ids plus DELETE means bam!, the second could leak special CouchDB documents
          use Npolar::Rack::ValidateId
          run ::Rack::Client::Handler::NetHTTP
        end
      end

      def limit
        @limit ||= LIMIT
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
      #if body.respond_to? :body and body.body.respond_to? :force_encoding
      #  body = body.body.force_encoding("UTF-8")
      #end