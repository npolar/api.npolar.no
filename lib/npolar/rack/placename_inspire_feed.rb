require "atom"
require "yajl"
require "uuidtools"
require "nokogiri"
require "uri"
require "hashie"

module Npolar

  module Rack

    # [Atom feed RFC4287](http://tools.ietf.org/html/rfc4287) of placenames in Norwegian polar areas,
    # extended with
    # * [INSPIRE Geographical Names](http://inspire.ec.europa.eu/documents/Data_Specifications/INSPIRE_DataSpecification_GN_v3.1.pdf) data specification
    # * [Atom publishing protocol RFC5023)(https://tools.ietf.org/html/rfc5023) - the "edit" and collection partial list ("first", "next", "previous", and "last") link relations
    # * [Atom License Extension RC4946](https://tools.ietf.org/html/rfc4946) - "license" link relation
    # * [OpenSearch 1.1](http://www.opensearch.org/index.php?title=Specifications/OpenSearch/1.1)
    #
    # @todo Notice: This middleware is tailored against the deprecated Solr-style Placenames JSON
    # @todo All @todos below should be solved upstream
    # @todo <link rel="search" type="application/opensearchdescription+xml" href="http://example.com/opensearchdescription.xml"/>
    # @todo Consider [The Atom "deleted-entry" Element RFC6721](https://tools.ietf.org/html/rfc6721)
    # @todo Consider [Feed Paging and Archiving RFC5005](https://tools.ietf.org/html/rfc5005)
    # @todo Consider [Web Linking RFC5988](https://tools.ietf.org/html/rfc5988)
    #
    # Useful links:
    # * http://inspire.ec.europa.eu/documents/Network_Services/Technical_Guidance_Download_Services_3.0.pdf
    # * http://inspire-geoportal.ec.europa.eu/schemas/inspire/
    # * http://inspire-foss.googlecode.com/ - in particular the [validator](https://code.google.com/p/inspire-foss/source/browse/trunk/tools/validator/#validator%2Fbin)
    # * https://tools.ietf.org/html/draft-mayrhofer-geopriv-geo-uri-01
    # * http://jira.codehaus.org/browse/GEOT-4160 "HTTP URIs are current OGC policy: "In June 2010 OGC revised the naming policy to use http URIs to identify persistent OGC resources instead of URNs.""
    # * http://www.eionet.europa.eu/aqportal/pmeet/AQDpil9/Day1_Session4_1215_e-Reporting_INSPIRE_namspaces.pdf
    class PlacenameInspireFeed < Npolar::Rack::Middleware

      ATOM_NS = "http://www.w3.org/2005/Atom"
      ATOM_MEDIATYPE = "application/atom+xml;type=feed"
      INSPIRE_BASE_NS = "urn:x-inspire:specification:gmlas:BaseTypes:3.2"
      INSPIRE_GN_NS = "urn:x-inspire:specification:gmlas:GeographicalNames:3.0"
      NPOLAR_LOGO_URI = "http://www.npolar.no/system/modules/no.npolar.site.npweb/resources/style/np-logo.svg"
      OPENSEARCH_NS = "http://a9.com/-/spec/opensearch/1.1/"
      PLACENAMES_METADATA_UUID = "a2813eb6-e866-4ef7-8808-ed09eb1566c5"
      LICENCE_URI = "http://creativecommons.org/licenses/by/4.0/"
      
      # Helper for getting English terrain names
      # JSON.parse(URI.parse("http://placenames.npolar.no/terreng.json").read).map {|t| t["terrain"]}.map {|t| { t["id"] => t["en"]} }.to_h
      def self.terrains
        { 48=>"Area, district", 162=>"Lava stream", 161=>"Crater", 74=>"Airfield", 75=>"Anchorage", 76=>"Bank", 77=>"Bay", 78=>"Beacon", 80=>"Build cluster",
          81=>"Cairn", 82=>"Cave", 83=>"Church", 85=>"Deep", 87=>"Fjord", 89=>"Glacier", 91=>"Hill", 92=>"Historic Settlement", 93=>"House", 94=>"Ice dome",
          96=>"Island", 97=>"Lake", 101=>"Mine", 102=>"Monument", 103=>"Moraine", 104=>"Mountain", 105=>"Protected area", 106=>"Ocean", 107=>"Ocean current",
          108=>"Pass", 109=>"Peninsula", 110=>"Plain, expanse, plateau", 112=>"Point", 113=>"Radio station", 115=>"Recognized claim", 116=>"River, brook",
          117=>"River outlet", 118=>"Road", 119=>"Islet, skerry, rock", 121=>"Rock face, precipice, cliff", 123=>"Scree", 124=>"Shoal, shallow, reef",
          125=>"Shore, coast", 126=>"Slope", 128=>"Spring", 129=>"Station", 131=>"Strait, sound", 133=>"Submarine channel", 135=>"Undersea feature",
          141=>"Territory", 142=>"Area, district, region", 143=>"Valley, ravine", 146=>"Waterfall", 148=>"Rock", 149=>"Alluvial plain", 156=>"Island group",
          157=>"Submarine slope", 158=>"Submarine ridge", 159=>"Meteorological station", 160=>"Settlement", 150=>"Crevasse", 151=>"Ice-depression, corrie, cirque",
          153=>"Ice-fall", 154=>"Ice-shelf", 155=>"Place name"}
      end
      
      # English terrain name (local feature type)
      def self.terrain(id)
        if not terrains.key?(id.to_i)
          id = 155
        end
        terrains[id.to_i]
      end
      
      # Condition fulfilled? Trigger when format=atom&variant=inspire [or when Accept: "application/atom+xml" and variant=inspire]
      # The variant parameter protects against middleware collision other Atom feed middleware
      def condition?(request)
        if "GET" == request.request_method and request["variant"] == "inspire" and ("atom" == request.format or request.accept_format =~ /application\/atom+xml/)
          true
        else
          false
        end
      end

      # Only called if #condition? is true
      def handle(request)
        # @todo Change request format to JSON (needed if upstream middleware reacts to format=atom)
        # @todo Or, if the future upstream Atom XML contains all necessary information, lean on this to avoid reinventing the wheel
        status, upstream_headers, body = app.call(request.env)
          if status < 300
            @json_feed = ::Yajl::Parser.parse(body.join(), symbolize_keys: true)[:feed]
            [status, upstream_headers.merge(header), [atom_feed.to_xml({indent: 2})] ]
          else
            [status, upstream_headers, body]
          end
      end
      
      # Return Atom feed with INSPIRE GeographicalNames NamedPlace
      # @return [Nokogiri::XML::Document] Atom feed
      # https://tools.ietf.org/html/rfc4287
      def atom_feed   
        atom_entries = @json_feed[:entries].map {|placename|
          atom_entry(placename)
        }
        
        atom_feed_uri = URI.parse(request.url)
        json_feed_uri = geojson_uri = URI.parse(request.url.gsub(/\&variant=inspire/, ""))
        json_feed_uri.query = json_feed_uri.query.gsub(/format=atom/, "format=json")
        geojson_uri.query = geojson_uri.query.gsub(/format=atom/, "format=geojson&fields=latitude:north,longitude:east,title,terrain,updated,approved,country,location,ident")

        # Step 1: Create Atom feed 
        atom_feed = Atom::Feed.new do |f|
          
          f.authors << Atom::Person.new(name: "Norwegian Polar Institute", uri: "http://npolar.no")
          f.contributors << Atom::Person.new(name: "Norwegian Polar Data", uri: "https://data.npolar.no", email: "data@npolar.no")
          
          #f.generator = self.class.name
          f.id = atom_feed_uri
          
          # AtomPub collection partial lists ie. "self", "next", "previous", "first", "last"
          if @json_feed.key?(:list)
            @json_feed[:list].select {|rel,uri| uri != false }.each do |rel, uri|
              f.links << Atom::Link.new(href: uri, rel: rel, type: "application/atom+xml")
            end
          end
          # @todo elsif feed links ...
          
          f.links << Atom::Link.new(href: "http://placenames.npolar.no", rel: "related", type: "text/html", title: "Place names in Norwegian polar areas", hreflang: "en")
          
          f.links << Atom::Link.new(href: "https://data.npolar.no/dataset/#{PLACENAMES_METADATA_UUID}", rel: "related", type: "text/html", hreflang: "en")
          f.links << Atom::Link.new(href: geojson_uri, rel: "alternate", type: "application/vnd.geo+json")
          f.links << Atom::Link.new(href: json_feed_uri, rel: "alternate", type: "application/json")
          
          f.links << Atom::Link.new(href: "http://api.npolar.no/dataset/#{PLACENAMES_METADATA_UUID}.dif", rel: "describedby", type: "application/xml", hreflang: "en")
          f.links << Atom::Link.new(href: "http://api.npolar.no/dataset/#{PLACENAMES_METADATA_UUID}.iso", rel: "describedby", type: "application/vnd.iso.19139+xml", hreflang: "en")
          f.links << Atom::Link.new(href: "https://data.npolar.no/dataset/#{PLACENAMES_METADATA_UUID}", rel: "describedby", type: "text/html", hreflang: "en")

          f.title = "Norwegian polar place names"
          f.subtitle = "This Atom feed is conformant to the INSPIRE data specification for the theme Geographical Names"
          
          f.rights = LICENCE_URI
          
          f.entries = atom_entries
          
        end
        
        atom_feed.updated = atom_feed.entries.select {|e| e.updated }.uniq.map {|u|
          u.updated 
        }.max
            
        atom_feed_xml = atom_feed.to_xml
        
        # Step 2: Extend Atom feed
        @ndoc = Nokogiri::XML(atom_feed_xml) do |config|
          config.default_xml.noblanks
        end
        
        @ndoc.root["xml:lang"] = "en"
        @ndoc.root.add_namespace_definition("opensearch", OPENSEARCH_NS)
        @ndoc.root.add_namespace_definition("gn", INSPIRE_GN_NS)
        @ndoc.root.add_namespace_definition("base", INSPIRE_BASE_NS)
        @ndoc.root.add_namespace_definition("gml", "http://www.opengis.net/gml/3.2")
        @ndoc.root.add_namespace_definition("xsi", "http://www.w3.org/2001/XMLSchema-instance")
        @ndoc.root.add_namespace_definition("gmd", "http://www.isotc211.org/2005/gmd")
        
        @ndoc.root["xsi:schemaLocation"] = "#{INSPIRE_GN_NS} http://inspire.ec.europa.eu/schemas/gn/3.0/GeographicalNames.xsd"

# {OPENSEARCH_NS} http://inspire-geoportal.ec.europa.eu/schemas/inspire/atom/1.0/opensearch.xsd"
# {ATOM_NS} atom.xsd.xml
# http://www.w3.org/1999/xhtml http://www.w3.org/2002/08/xhtml/xhtml1-strict.xsd
        
        # Insert atom:logo after links
        logo = node("logo")
        logo.content = NPOLAR_LOGO_URI
        links = @ndoc.xpath("/atom:feed/atom:link", atom: ATOM_NS)
        links.last.add_next_sibling(logo)
        
        # Insert opensearch elements before links
        totalResults = node("opensearch:totalResults")
        opensearch =  @json_feed[:opensearch]
        totalResults.content = opensearch[:totalResults]
        links.first.add_previous_sibling(totalResults)
        
        items_per_page = node("opensearch:itemsPerPage")
        items_per_page.content = opensearch[:itemsPerPage]
        totalResults.add_next_sibling(items_per_page)
        
        start_index = node("opensearch:startIndex")
        start_index.content = opensearch[:startIndex]
        items_per_page.add_next_sibling(start_index)
        
        # Insert gn:NamedPlace in each entry
        @ndoc.xpath('//xmlns:entry').each_with_index do |e,idx|
          placename = @json_feed[:entries][idx]
          e.add_child(gn_named_place(placename))
        end
        
        @ndoc

      end

      protected
      
      # @return [Atom::Entry] Atom entry
      def atom_entry(placename)
        placename = Hashie::Mash.new(placename) #Placename.new(placename)
        entry = ::Atom::Entry.new do |e|
          uuid = placename.id =~ /^\w{8}[-]\w{4}-\w{4}-\w{4}-\w{12}$/ ?  placename.id : uuid(placename.ident)
          e.id = "http://api.npolar.no/placename/#{uuid}"
          e.title = placename[:title]
         
          e.links << Atom::Link.new(href: "https://api.npolar.no/placename/#{uuid(placename.ident)}", rel: "edit", type: "application/json")
          e.links << Atom::Link.new(href: "http://placenames.npolar.no/stadnamn/#{placename.title_link}?ident=#{placename.ident}", rel: "alternate", type: "text/html")
          if placename.title_replaced_by != ""
            e.links << Atom::Link.new(href: "http://placenames.npolar.no/stadnamn/#{URI.encode(placename.title_replaced_by)}?ident=#{placename.ident_replaced_by}", rel: "related", type: "text/html")
          end
          
          (placename.links||[]).each do |link|
            e.links << ::Atom::Link.new(:href => link.href, :title => link.title, :rel => link.rel, :type => link.type, hreflang: link.hreflang)
          end
          
          # http://tools.ietf.org/html/rfc4946#page-3
          e.links << ::Atom::Link.new(:href => LICENCE_URI, :rel => "license", :type => "text/html", hreflang: "en")
          
          e.links = e.links.uniq
          
          e.categories << ::Atom::Category.new(:term => placename[:approved] == true ? "official" : "historical", scheme: "http://inspire.ec.europa.eu/codelist/NameStatusValue/")
          e.categories << ::Atom::Category.new(:term => gn_type_value(placename), scheme: "http://inspire.ec.europa.eu/codelist/NamedPlaceTypeValue/")
          e.categories << ::Atom::Category.new(:term => country_code(placename.location), scheme: "http://psi.oasis-open.org/iso/3166/") # http://en.wikipedia.org/wiki/ISO_3166-2:NO
          e.categories << ::Atom::Category.new(:term => placename[:location], scheme: "http://api.npolar.no/schema/placename#area")
          
          content = ::Atom::Content::Xhtml.new(atom_content(placename))
          content.xml_lang = "en"     
          e.content = content
          
          if placename.published.nil?
            e.published = Time.parse(placename[:created])
          else
            e.published = Time.parse(placename[:published])
          end
          e.updated = Time.parse(placename[:updated])
          
         
        end
        entry
      end
      
      # @todo See deprecated Placenames XML API for inspiration
      def atom_content(placename)
        @article = Nokogiri::XML('<div/>')
        if placename.title_replaced_by != ""
          @article.root.add_child(atom_content_section(:replaced_by, "Unofficial name, replaced by: #{placename[:title_replaced_by]}"))
        end
        @article.root.add_child(atom_content_section(:definition, placename[:definition]))        
        @article.root.add_child(atom_content_section(:origin, placename[:origin]))
        @article.root.add_child(atom_content_section(:proposer, placename[:proposer]))
        @article.root.add_child(atom_content_section(:note, placename[:note]))
        
        return @article.to_xml
      end
      
      def atom_content_section(field, content)
        node = node("div", @article)
        node["class"] = field.to_s
        node.content = content
        node
      end
      
      def country_code(location)
        case location
        when "Dronning Maud Land", "Peter I Øy"
          "AQ"
        when /^A(nta)?rktis$/
          ""
        else
          "NO"
        end
      end
      
      # A INSPIRE Named Place node with 1..* name variants for a given placename
      # @return [Nokogiri::XML::Node]
      def gn_named_place(placename)
        
        id = uuid(placename[:ident]) # @todo check if placename id is uuid or uri 
        latitude = placename[:latitude] || placename[:north] || 0.0
        longitude = placename[:longitude] || placename[:east] || 0.0
        #altitude = placename[:altitude] || placename[:height] || 0.0
        published = placename.key?(:published) ? placename[:published] : placename[:created]

        # gn:NamedPlace        
        named_place = node "gn:NamedPlace"    
        named_place["gml:id"] = "placename-#{id}"
            
        # gn:beginLifespanVersion
        begin_lifespan_version = node "gn:beginLifespanVersion"
        begin_lifespan_version.content = published
        named_place.add_child(begin_lifespan_version)
        
        # gn:geometry  
        geometry = node "gn:geometry"
    
        point = node "gml:Point"
        point["gml:id"] = "point-#{id}"
        
        # EPSG:4936 = 3D; EPSG:4258 = 2D, both [ETRS89](http://en.wikipedia.org/wiki/European_Terrestrial_Reference_System_1989)
        # EPSG:4326 = [WGS84](http://en.wikipedia.org/wiki/World_Geodetic_System#A_new_World_Geodetic_System:_WGS_84)
        point["srsName"] = "http://www.opengis.net/def/crs/EPSG/0/4936"
            
        pos = node "gml:pos"
        pos.content = "#{latitude} #{longitude}"
        pos["srsDimension"] = 2 #altitude != 0.0 ? "3" : "2"
                
        named_place.add_child(geometry)
        geometry.add_child(point)
        point.add_child(pos)
        
        # gn: inspireId
        inspire_id = node "gn:inspireId"
        named_place.add_child(inspire_id)
            
        identifier = node("base:Identifier")
        inspire_id.add_child(identifier)

        local_id = node("base:localId")
        local_id.content = id
        identifier.add_child(local_id)
            
        namespace = node "base:namespace"
        namespace.content = "http://api.npolar.no/placename"            
        identifier.add_child(namespace)
        
        # gn:LocalType (2 nn/en)
        named_place.add_child(gn_local_type("nn", placename[:terrain]))
        named_place.add_child(gn_local_type("en", self.class.terrain(placename[:terrainid])))
        
        # gn:name (1..*)
        named_place.add_child(gn_name(placename))

        if placename[:approved]
          if not request["reject-nameStatus"] == "historical"
            placenames_from_variants(placename).each do | variant |
              named_place.add_child(gn_name(variant))
            end
          end
        end
        
        # gn:type
        gn_type_node = node("gn:type")     
        gn_type_node.content = gn_type_value(placename)
        named_place.add_child(gn_type_node)
            
        named_place
      end
           
      def gn_name(placename)
        # gn:name
        name = node "gn:name"
        
        # gn:GeographicalNames
        geographical_name = node "gn:GeographicalName"
        name.add_child(geographical_name)
        
        
        # gn:language
        language = node("gn:language")
        if placename[:approved]     
          language.content = "nno"  
        else
          # Language and nativeness is only known for approved names, nilReason attribute: http://schemas.opengis.net/gml/3.2.1/basicTypes.xsd
          language["nilReason"] = "unknown"
        end
        geographical_name.add_child(language)
        
        # gn:nativeness
        nativeness = node("gn:nativeness")
        if placename[:approved]
          nativeness.content = "endonym"
        else
          nativeness["nilReason"] = "unknown"
        end
        geographical_name.add_child(nativeness)
        
        # gn:nameStatus
        name_status = node("gn:nameStatus") # standardised vs official?
        name_status.content = placename[:approved] ? "official" : "historical"
        geographical_name.add_child(name_status)
        
        source_of_name = node("gn:sourceOfName")
        source_of_name.content = "Norwegian Polar Institute"
        if (placename.key?(:reference) and placename[:reference].size > 0) or (placename.key?(:proposer) and placename[:proposer].size > 0)
          from = ([placename[:proposer]]||[]+placename[:reference]||[]).uniq.join(", ")
          if from != ""
            source_of_name.content += "; from #{from}"
          end
        end
        geographical_name.add_child(source_of_name)
        
        pronunciation = node("gn:pronunciation")
        pronunciation.add_child(node("gn:PronunciationOfName"))
        geographical_name.add_child(pronunciation)
        
        spelling = node "gn:spelling"
        geographical_name.add_child(spelling)
        
        spelling_of_name = node "gn:SpellingOfName"
        spelling.add_child(spelling_of_name)

        text = node "gn:text"
        script = node "gn:script"
        
        text.content = placename[:title]||placename[:name]
        script.content = "Latn"
        spelling_of_name.add_child(text)
        spelling_of_name.add_child(script)
        
        name
      end
      
      def gn_local_type(lang, content)
        local_type = node("gn:localType")
        lcs = node("gmd:LocalisedCharacterString")
        local_type.add_child(lcs)
        lcs["locale"] = lang
        lcs.content = content
        local_type
      end

      # Convert http://placenames.npolar.no/terreng => http://inspire.ec.europa.eu/codelist/NamedPlaceTypeValue/
      def gn_type_value(placename)
        case placename[:terrainid]

       when 48, 141, 142
          "administrativeUnit"
        when 76, 85, 97, 107, 116, 117, 124, 128, 133, 135, 146, 157, 158
          "hydrography"
        when 105
          "protectedSite"
        when 80, 160
          "populatedPlace"
        when 74, 118
          "transportNetwork"
        when 83, 93, 129, 159
          "building"
        when 89, 103, 123, 149, 150, 162   
          "landcover"
        when 77, 82, 87, 91, 94, 96, 104, 106, 108, 109, 110, 112, 119, 121, 125, 126, 131, 143, 148, 151, 153, 154, 156, 161    
          "landform"
        else
         "other"
        end
      end
      
      def node(name, document=nil)
        document = document.nil? ? @ndoc : document
        Nokogiri::XML::Node.new(name, document)
      end

      def placenames_from_variants(placename)
        i = -1
        placename = Hashie::Mash.new(placename)
        placename.ident_variants.select {|ident| ident =~ /^\d+$/ }.map {|ident|
          i = i + 1 
          { id: uuid(ident),
            ident: ident,
            approved: placename.approved_variants[i],
            title: placename.title_variants[i]
          }
        }
      end
      
      def header
        type = ATOM_MEDIATYPE
        if request["type"] == "xml"
          type = "application/xml"
        end
        {"Content-Type" => "#{type}; charset=utf-8"}
      end
      
      def uuid(ident)
        if not ident.to_s =~ /\d+/
          raise ArgumentError, "Legacy ident should be a positive integer"
        end
        UUIDTools::UUID.sha1_create(UUIDTools::UUID_URL_NAMESPACE, "http://placenames.npolar.no/stadnamn/#{ident}")
      end
      
    end
  end
end