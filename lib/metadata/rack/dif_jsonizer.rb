require "atom"
require "gcmd/dif_builder"
require "yajl"
require "uuidtools"

module Metadata

  module Rack

    class DifJsonizer < Npolar::Rack::Middleware

      FORMATS = ["atom", "dif", "iso", "xml"]

      ACCEPTS = ["xml", "dif"]

      XML_HEADER_HASH = {"Content-Type" => "application/xml; charset=utf-8"}

      ATOM_HEADER_HASH = {"Content-Type" => "application/atom+xml; charset=utf-8"}
      # The official is atom+xml but browsers refuse to display nice XML anymore :)

      ISO_HEADER_HASH = {"Content-Type" => "application/vnd.iso.19139+xml; charset=utf-8"}

      JSON_HEADER_HASH = {"Content-Type" => "application/json; charset=utf-8"}
      
      XSL = "DIF-ISO-3.1.xsl"

      def condition?( request )
        # GET
        if (FORMATS.include? request.format or request.content_type =~ /application\/xml/) and "GET" == request.request_method
          true
        # POST, PUT
        elsif (ACCEPTS.include? request.format or request.content_type =~ /application\/xml/) and ["POST","PUT"].include? request.request_method
          true
        else
          false
        end
      end

      # Only called if #condition? is true
      def handle(request)
        case request.request_method
          when "GET" then xml_from_json(request)
          when "POST", "PUT" then dif_save(request)
        end
      end

      # Saves DIF XML as JSON
      # Transforms incoming DIF XML to JSON, sets a new input body with corresponding headers
      # FIXME PUT DIF XML does not work!
      def dif_save(request)
        
        # Build Hash of DIF XML(s)
        xml = request.body.read
        builder = ::Gcmd::Dif.new( xml )
        difs = builder.document_to_array
        j = []
        difs.each do | dif_hash |
          transformer = ::Metadata::DifTransformer.new( dif_hash )
          #transformer.base = request.url.gsub(/\/\?#{request.query_string}/, "")
          metadata_dataset = transformer.to_dataset
          j << metadata_dataset
        end

        # Modify request
        json = j.to_json

        #request.env["PATH_INFO"] = request.env["PATH_INFO"].split(".").first + ".json" #XXX
        request.env["CONTENT_TYPE"] = "application/json"
        request.env["CONTENT_LENGTH"] = json.bytesize.to_s
        request.env["rack.input"] = ::Rack::Lint::InputWrapper.new( StringIO.new( json ) )

        # Save by passing on the request - now with JSON body
        app.call(request.env)
      end


      # On GET
      # Return DIF XML from Dataset JSON
      def xml_from_json(request)

        response = app.call(request.env)

        if response.status < 300

          metadata_dataset = ::Yajl::Parser.parse(response.to_s)

          # if id false? and many => pack xml in somethimg p metadata_dataset

          xml = case request.format
            when "dif", "xml" then begin
              header = XML_HEADER_HASH
              dif_xml(dif_json(metadata_dataset))
              end
            when "atom" then begin
              header = ATOM_HEADER_HASH
              atom_entry(metadata_dataset).to_xml
              end
            when "iso", "19139" then begin
              header = ISO_HEADER_HASH
              iso(dif_xml(dif_json(metadata_dataset)))
              end
          end

          if "validate" == request.path_info.split("/").last and xml =~ /DIF/
            schema = ::Gcmd::Schema.new
            report = schema.validate( xml )
            
            valid = report.any? ? false : true
            
            status = valid==false ? 422 : 200
            
            if valid
              error = error_hash(status, "Valid")["error"]
              error["valid"] = true
            else
              error = error_hash(status, "Validation failed")["error"]
              error["valid"] = false
              error["report"] = report
              error["schema"] = schema.schema_location
            end
            error = error.select {|k,v| k !~ /^(ip|params|username|host|level|agent|format|path)/}
            [status, JSON_HEADER_HASH, [error.to_json]]

          else
            
            [200, header, [xml]]
          end

        else
          response
        end
      end

      protected
      
      def namespaced_uuid( id, namespace = NAMESPACE )
        UUIDTools::UUID.sha1_create( UUIDTools::UUID_DNS_NAMESPACE, namespace + id )
      end

      def dif_json(metadata_dataset)
        Metadata::Dataset.new( metadata_dataset ).to_dif_hash
      end

      def dif_xml(dif_json)
        builder = ::Gcmd::DifBuilder.new( dif_json )
        builder.build_dif
      end

      def atom_entry(metadata_dataset)
        dataset = dataset = Metadata::Dataset.new(metadata_dataset)
        entry = ::Atom::Entry.new do |e|
          e.id = dataset.id =~ /^\w{8}[-]\w{4}-\w{4}-\w{4}-\w{12}$/ ? "urn:uuid:#{dataset.id}" : dataset.id

          e.title = dataset["title"] unless dataset["title"].nil?
          e.summary = dataset["summary"] unless dataset["summary"].nil?
          #e.draft = dataset.draft

          dataset.authors.each do |author|
            e.authors << ::Atom::Person.new(:name => author.first_name+" "+author["last_name"], :email => author.email)
          end
          dataset.people.reject {|p| dataset.authors.include? p}.each do |c|
            e.contributors << ::Atom::Person.new(:name => c.first_name+" "+c.last_name, :email => c.email)
          end

          e.links = []

          (dataset.links||[]).each do |link|
            e.links << ::Atom::Link.new(:href => link.href, :title => link.title, :rel => link.rel, :type => link.type)
          end
          # http://tools.ietf.org/html/rfc4946#page-3
          (dataset.licences||[]).each do |href|
            e.links << ::Atom::Link.new(:href => href, :rel => "license", :type => "text/html")
          end
          (dataset.organisations||[]).each do |o|
            e.links << ::Atom::Link.new(:href => "http://api.npolar.no/organisation/"+o.id, :rel => "organisation", :type => "application/json")
          end

          ##e.links << ::Atom::Link.new(:href => ".dataset", :type => "application/dataset+xml", :rel => "self")

          e.categories = []
          
          e.categories += (dataset||[]).topics.map {|topic|
            ::Atom::Category.new(:term => topic, :scheme => "http://api.npolar.no/schema/topics")
          }
          e.categories += (dataset.iso_topics||[]).map {|topic|
            ::Atom::Category.new(:term => topic, :scheme => "http://api.npolar.no/schema/iso_topics")
          }
          if dataset.category? and dataset.category.respond_to?(:each)
            dataset["category"].each do |category|
              e.categories << ::Atom::Category.new(:term => category["term"], :scheme => category["schema"], :label => category["label"])
            end
          end
          e.categories += (dataset.tags||[]).map {|tag|
            ::Atom::Category.new(:term => tag)
          }
          e.categories += (dataset.sets||[]).map {|set|
            ::Atom::Category.new(:term => set)
          }

          e.categories += (dataset.placenames||[]).map {|p|
            ::Atom::Category.new(:term => p.placename)
          }
          e.categories << ::Atom::Category.new(:term => dataset.progress)

          e.summary = dataset.summary
          
          if dataset.gcmd? and dataset.gcmd.sciencekeywords?
            dataset.gcmd.sciencekeywords.each do |p|
              p.each do |k,v|
                e.categories << ::Atom::Category.new(:term => v, :scheme => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/##{k}")
              end
            end
          end

          if dataset.gcmd? and dataset.gcmd.idn_nodes?
            dataset.gcmd.idn_nodes.each do |idn_node|
              e.categories << ::Atom::Category.new(:term => idn_node.Short_Name, :scheme => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/#IDN_Node")
            end
          end          


          unless dataset.published.nil?
            e.published = Time.parse(dataset["published"])
          end
          unless dataset.updated.nil?
            e.updated = Time.parse(dataset["updated"])
          end

          # e.rights = dataset.rights

        end
        entry
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
