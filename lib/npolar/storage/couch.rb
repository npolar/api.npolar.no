require "rack/client"

module Npolar
  module Storage

    # CouchDB storage client
    # Needs drying, esp. share code between POST and PUT (before: valid?)
    class Couch

      # Delegate validation to model
      #extend Forwardable # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/forwardable/rdoc/Forwardable.html
      #def_delegators :model, :valid?
  
      JSON_ARRAY_REGEX = /^(\s+)?\[.*\](\s+)?$/

      ALL_DOCS_QUERY_REGEX = /^\s*\{\s*"keys"\s*:.*$/

      LIMIT = 1000000
  
      HEADERS = {
        "Accept" => "application/json",
        #Accept-Encoding? 
        "Content-Type" => "application/json; charset=utf-8",
        "User-Agent" => self.name }

      attr_accessor :accepts, :client, :headers, :read, :write, :formats, :model, :limit

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
        @accepts ||= ["application/json"]
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
        # if revision not provided, go and fetch latest rev number; store in params
        if !params.has_key?('rev')
          response = writer.get(id, params)
          if response.status == 200
            couch = JSON.parse(response.body)
            params["rev"] = couch["_rev"]
          end
        end

        log.debug "About to delete id = #{id} with rev = #{params['rev']}"

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
          when nil, "", "_ids", "" then ids
          when "_feed", "_all" then feed(params)
          when "_invalid" then valid(false, params)
          when "_valid" then valid(true, params)
          when "_validate" then validate(params)

        else
          response = reader.get(id, headers, params)
          [response.status, response.headers, response.body]
        end
        
      end
  
      def head(id, params={})
        # FIXME => 500
        response = reader.head(id, headers, params)
        [response.status, response.headers, response.body]
      end
  
      def headers
        @headers ||= HEADERS
      end

      def valid(cond=true, params=nil)
        v = all.select {|d| cond == model.class.new(d).valid? }
        body = Yajl::Encoder.encode(v)
        Rack::Response.new(body, 200, {"Content-Type" => HEADERS["Content-Type"]})
      end

      def validate(params)
        report = []
        all.each do |d|
          m = model.class.new(d)
          v = m.valid?
          if false == v
            report << { d[:id] => m.errors }
          end
        end
        report = { "errors" => report }
        body = Yajl::Encoder.encode(report)
        Rack::Response.new(body, 200, {"Content-Type" => HEADERS["Content-Type"]})
      end

      def all
        response = couch.get(all_docs_uri(true))
        if 200 == response.status
          Yajl::Parser.parse(response.body, :symbolize_keys => true)[:rows].map { |row| row[:doc] }
        else
          raise "HTTP error: #{response.status}"
        end
      end
  
      def post(data, params={})
        #unless valid? data
        #  raise Exception
        #end

        if data =~ ALL_DOCS_QUERY_REGEX
          # XXX ugly hack to route request to right place
          return fetch_many(data, include_docs=true)
        elsif data =~ JSON_ARRAY_REGEX
          post_many(data, params)
        else
          unless data.is_a? Hash
            doc = Yajl::Parser.parse(data)
            doc = self.class.force_ids(doc)
          end

          # Turn POST into PUT so that we get a real UUID id?

          #HTTP/1.1 201 Created
          #Content-Type: application/json
          #Server: CouchDB/1.2.0 (Erlang OTP/R15B01)
          #Location: http://localhost:5984/api/svc-polar-bear-interaction
          #Etag: "1-bf53e26c83adaaf5c4e3cb12ca018a4e"
          #Date: Wed, 19 Dec 2012 11:44:56 GMT
          #Content-Length: 674
          #Cache-Control: must-revalidate
          #Connection: keep-alive

          response = writer.put(doc["id"], headers, doc.to_json)

          # if conflict, and overwrite=true, autoresolve it
          if 409 == response.status and params["overwrite"] == "true"
            couch = Yajl::Parser.parse(response.body)
            if couch["error"] == "conflict"
              doc = update_revision(doc)
              response = writer.put(doc["id"], headers, doc.to_json)
            end
          end
          
          if 201 == response.status
            couch = Yajl::Parser.parse(response.body)
            response = reader.get(couch["id"], {"rev" => couch["rev"] })
          end

          [response.status, response.headers, response.body]
  
        end
  
      end
  
      # @param String id UUID or SHA1 hash, e.g. "69f3f072-27a0-4d25-a5bf-aac8f7e31d8f"
      # @param String|Hash data JSON data
      # @param Hash params
      # @todo force "_id" 
      def put(id, data, params={})

        if data.is_a? Hash
          data = data.to_json
        end
        #unless valid? data
        #  raise Exception
        #end
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
          couch_desc = Yajl::Parser.parse(response.body)
          meta = {
            "count" => couch_desc["doc_count"],
            "data_size" => couch_desc["data_size"],
            "updated" => nil
          } 
          status = 200
        else
          status = 501
        end
        [status, {"Content-Type" => HEADERS["Content-Type"]}, [ Yajl::Encoder.encode(meta)+"\n"]] # Couch returns text/plain here!?
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
        body = Yajl::Encoder.encode({ "ids" => ids })
        headers = {"Content-Type" => HEADERS["Content-Type"]}
        #[status, headers, Yajl::Encoder.encode(body)+"\n"] # Couch returns text/plain here!?
        Rack::Response.new(body, status, headers)
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

      # retrieve all docs matching requested id's
      # data takes form of { "keys" : [1, 2, 3, 4, 5] } 
      def fetch_many(data, include_docs=false)
        uri = "#{read}/_all_docs?"
        if include_docs
          uri += "include_docs=true"
        end
        response = reader.post(uri, headers, data)
        [response.status, response.headers, response.body]
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

      def valid? data, context="POST"
        @errors = []

        # First, check JSON syntax
        begin
          if data =~ JSON_ARRAY_REGEX
            docs = JSON.parse data
          else
            docs = []
            docs << JSON.parse(data)
          end

        rescue JSON::ParserError => e        
          @errors = "JSON syntax error"
          return false
        end

        if model.nil?
          return true
        end
        
        begin
          docs.each do | document |
          
            # @model already exists, but we need a new clean object
            m = model.class.new(document)

            v =  m.valid? document            
            if false == v and m.respond_to? :errors
               @errors << { document["id"] => m.errors }
            end
          end
          @errors = errors.flatten

          errors.any? ? false : true

        rescue => e
          raise e
        end
      end

      def errors
        @errors ||= nil
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
          # Blank ids plus DELETE means bam! (deleting entire collection), the second could leak special CouchDB documents
          use Npolar::Rack::ValidateId
          run ::Rack::Client::Handler::NetHTTP
        end
      end

      # look up couch doc by doc["id"] and update doc's _rev
      def update_revision(doc)
        response = get(doc["id"])
        if response[0] == 200
          couch_doc = Yajl::Parser.parse(response[2])
          rev = couch_doc["_rev"]
          doc["_rev"] = rev
        end
        doc
      end

      def ids_from_response(response)
        ids = []
        # couch responds with id's of written docs, parse them out
        info = Yajl::Parser.parse(response.body)
        info.each { |row| ids << row['id'] }
        ids
      end

      def self.force_ids(doc)
        # if _id defined make sure id=_id
        if doc.key? "_id" and !doc["_id"].to_s.empty?
          doc["id"] = doc["_id"]
        # if _id not defined and id defined, _id=id
        elsif doc.key? "id" and !doc["id"].to_s.empty?
          doc["_id"] = doc["id"]
        # no _id or id, then generate uuid and set _id=id=uuid
        else
          doc["_id"] = self.uuid(doc)
          doc["id"] = doc["_id"]
        end
        doc
      end

      def self.uuid(doc)
        UUIDTools::UUID.timestamp_create
      end

      def limit
        @limit ||= LIMIT
      end

      def log
        @log ||= Npolar::Api.log
      end
  
      def reader
        client(read+"/")
      end      
      
      def writer
        client(write+"/")
      end

      def post_many(data, params={})        
        if data !~ JSON_ARRAY_REGEX
          raise ArgumentException, "Please provide data as JSON Array"
        end
        t0 = Time.now

        # parse docs and make sure we have 'id' and '_id' set
        docs = Yajl::Parser.parse(data)
        docs = docs.map {|doc| self.class.force_ids(doc)} 

        # try to post them all
        couch =  { "docs" => docs }
        response = writer.post("_bulk_docs", headers, couch.to_json)

        # keep ids here
        conflict_ids = []
        couch_ids = []

        # inspect for any conflicts
        messages = Yajl::Parser.parse(response.body)
        messages.each do |msg|
          if msg.has_key? "error" and msg["error"] == "conflict"
            # collect any conflicted ids
            conflict_ids << msg["id"]
          end

          # collect all generated ids
          couch_ids << msg["id"]
        end

        # if we had conflicts
        status = !conflict_ids.empty? ? 409 : response.status

        # if overwrite=true then repost with updated _revs, overwriting docs in db
        if params["overwrite"] == "true" and !conflict_ids.empty?
          # docs we will repost
          docs_to_repost = []

          # hash the docs by id
          docs_hash = Hash[docs.collect { |doc| [doc["id"], doc]}]

          # update _revs of docs
          resp = fetch_many({ "keys" => conflict_ids }.to_json, include_docs=false)
          resp_data = Yajl::Parser.parse(resp[2])
          resp_data["rows"].each do |info|
            if docs_hash.has_key? info["id"]
              doc = docs_hash[info["id"]]
              doc["_rev"] = info["value"]["rev"]
              docs_to_repost << doc
            end
          end 

          # repost to _bulk_docs
          response = writer.post("_bulk_docs", headers, { "docs" => docs_to_repost }.to_json)
          status = response.status
        end

        headers = {"Content-Type" => HEADERS["Content-Type"]}
        elapsed = Time.now-t0
        size = couch['docs'].size

        if 201 == status
          summary = "Posted #{size} CouchDB documents in #{elapsed} seconds"
          rk = "response"
          explanation =  "CouchDB success"
        elsif 409 == status
          summary = "document write conflict"
          explanation  = "CouchDB error"
          rk = "error"
        else
          summary = JSON.parse(response.body)["reason"]
          explanation =  "CouchDB error"
          rk = "error"
        end
        
        [status, headers , [{rk => { "status" => status,
          # "uri" => "",
          "ids" => couch_ids, # provide these so solrizer can use them
          "summary" => summary, "explanation" => explanation, "system" => response.headers["Server"] },
          "method" => "", "qps" => size/elapsed
          }.to_json+"\n"]]
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
