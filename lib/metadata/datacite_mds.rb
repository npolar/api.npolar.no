require "net/http"
require "uri"

module Metadata

  class DataciteMds

    MDS_URI = "https://mds.datacite.org"

    @@credentials = [nil, nil]
    @@testMode = true

    def self.credentials=c
       @@credentials=c
    end

    def self.testMode=testMode
      @@testMode=testMode
    end
    
    def self.testMode
      @@testMode
    end

    def self.registerDoi(doi, url, xml)
      sendMetadata(xml)
      bind(doi,url)
    end

    # `get': cannot access dataset which belongs to another party (RuntimeError)
    def self.getMetadata(doi)
      get("/metadata/#{doi}")
    end

    def self.sendMetadata(xml)
      post("/metadata?testMode=#{@@testMode}", xml)
    end

    def self.bind(doi,url)
      body = "doi=#{doi}\nurl=#{url}\n"
      post("/doi?testMode=#{@@testMode}", body, {"Content-Type"=>"text/plain"})
    end

    def self.dois
      get("/doi").body.split(/\n/).map {|doi| doi.downcase }
    end

    protected

    def self.get(path,headers={})
      uri = URI.parse("#{MDS_URI}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      username, password = @@credentials
      request.basic_auth username, password
      headers.keys.each do |key|
        request[key] = headers[key]
      end
      response = http.request(request)
      if response.code.to_i >= 300
        raise "GET #{uri}\n#{response.code}\n#{response.body}"
      end
      response
    end


    def self.post(path, body = "", headers={"Content-Type"=>"application/xml"})
      uri = URI.parse("#{MDS_URI}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri)
      username, password = @@credentials
      request.basic_auth username, password
      headers.keys.each do |key|
        request[key] = headers[key]
      end
      request.body = body
      response = http.request(request)
      if response.code.to_i != 201
        raise response.body
      end
      response

    end


  end
end