# encoding: utf-8
require "atom"
require "yajl"
require "uuidtools"

module Npolar

  module Rack

    class Atomizer < Npolar::Rack::Middleware

      FORMATS = ["atom"]

      ACCEPTS = []

      ATOM_HEADER_HASH = {"Content-Type" => "application/atom+xml; charset=utf-8"}

      GEORSS_XML_NS = "http://www.georss.org/georss"

      OPENSEARCH_XML_NS = "http://a9.com/-/spec/opensearch/1.1/"
      
      def condition?( request )
        if (FORMATS.include? request.format or request.content_type =~ /application\/atom+xml/) and "GET" == request.request_method
          true
        else
          false
        end
      end

      # Only called if #condition? is true
      def handle(request)
        @request = request
        case request.request_method
          when "GET" then atom_feed
          else raise "Not implemented"
        end
      end

      def atom_feed

        status, headers, bodyarr = app.call(request.env)
        if status < 300
          feed = ::Yajl::Parser.parse(bodyarr.join("\n"), :symbolize_keys => true)[:feed]
          [status, ATOM_HEADER_HASH, [atom_feed_builder(feed).to_xml]]

        else
          [status, headers, bodyarr]
        end
      end

      protected
      
      def namespaced_uuid( id, namespace = "" )
        UUIDTools::UUID.sha1_create( UUIDTools::UUID_DNS_NAMESPACE, namespace + id )
      end


#id
#A unique id for the feed.
#updated
#The Time the feed was updated.
#title
#The title of the feed.
#subtitle
#The subtitle of the feed.
#authors
#An array of Atom::Person objects that are authors of this feed.
#contributors
#An array of Atom::Person objects that are contributors to this feed.
#generator
#A Atom::Generator.
#categories
#A list of Atom:Category objects for the feed.
#rights
#A string describing the rights associated with this feed.
#entries
#An array of Atom::Entry objects.
#links
#An array of Atom:Link objects. (This is actually an Atom::Links array which is an Array with some sugar).

      def atom_feed_builder(feed)
        feed_builder = Atom::Feed.new do |f|
              f.title = "Norwegian Polar Data #{request["q"]}"
              f.links << Atom::Link.new(:href => request.url, :rel => "self")
              f.links << Atom::Link.new(:href => "NEXT", :rel => "next")
            
            
              f.updated = Time.now.utc
              f.authors << Atom::Person.new(:name => 'John Doe')
              f.id = "ID"
            
              f[OPENSEARCH_XML_NS, "totalResults"] << "#{ feed[:opensearch][:totalResults] }"
              f[OPENSEARCH_XML_NS, "startIndex"] << "#{ feed[:opensearch][:startIndex] }"
              f[OPENSEARCH_XML_NS, "itemsPerPage"] << "#{ feed[:opensearch][:itemsPerPage] }"
              #<opensearch:Query role="request" searchTerms="New York History" startPage="1" />
            
              if feed.is_a? Hash and feed.key? :entries
              
                feed[:entries].each do |entry|
            
                f.entries << Atom::Entry.new do |e|
                e.title = entry[:title] +" - "+ entry[:collection]
              
                #<link rel="search" type="application/opensearchdescription+xml" href="http://example.com/opensearchdescription.xml"/>
   
                if entry[:"edit-uri"]
                  e.links << Atom::Link.new(:href => entry[:"edit-uri"], :rel => "edit-media", :type=>"application/json", :hreflang=>"en")
                end    
            #e.links << Atom::Link.new(:href => "http://placenames.npolar.no/stadnamn/"+entry[:title_link]+"?lang=en", :rel => "alternate")
                e.id = "urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a"
                e.updated = Time.parse(entry[:updated])
                e.summary = entry[:summary]
                if entry[:north].abs.to_f > 0.0
                  e[GEORSS_XML_NS, "point"] << "#{ entry[:east] } #{ entry[:north] }"
                end
              end

            end
          end
        end
      end

      def iso(dif)
        tmp = Tempfile.new('dif')
        iso = ""
        begin
          tmp.write dif
          tmp.rewind
          xslfile = File.expand_path(File.dirname(__FILE__)+"/../../../public/xsl/#{XSL}")
          iso = `/usr/bin/saxonb-xslt -ext:on -s:#{tmp.path} -xsl:#{xslfile}`
        ensure
          tmp.close
          tmp.unlink
        end

        iso
      end


    end
  end
end
