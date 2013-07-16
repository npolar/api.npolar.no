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
          when "GET" then dif_from_json(request)
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

      def dif_from_json(request)

        response = app.call(request.env)

        if response.status < 300

          metadata_dataset = ::Yajl::Parser.parse(response.to_s)

          # if id false? and many => pack xml in somethimg p metadata_dataset

          xml = case request.format
            when "dif", "xml"
              then dif_xml(dif_json(metadata_dataset))
            when "atom"
              then atom_entry(metadata_dataset).to_xml
            when "iso"
              then iso(dif_xml(dif_json(metadata_dataset)))
          end

          if "validate" == request.path_info.split("/").last
            schema = ::Gcmd::Schema.new
            report = schema.validate_xml( xml )
            
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
            [200, XML_HEADER_HASH, [xml]]
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
        transform = Metadata::DifTransformer.new( metadata_dataset )
        transform.to_dif
      end

      def dif_xml(dif_json)
        builder = ::Gcmd::DifBuilder.new( dif_json )
        builder.build_dif
      end

      def atom_entry(metadata_dataset)
        atom = Metadata::Dataset.new(metadata_dataset)
        entry = ::Atom::Entry.new do |e|
          e.id = atom.id =~ /^\w{8}[-]\w{4}-\w{4}-\w{4}-\w{12}$/ ? "urn:uuid:#{atom.id}" : atom.id

          e.title = atom["title"] unless atom["title"].nil?
          e.summary = atom["summary"] unless atom["summary"].nil?

          #e.authors << ::Atom::Person.new(:name => 'John Doe')
          
          atom.investigators.each do |author|
            e.authors << ::Atom::Person.new(:name => author.first_name+" "+author["last_name"], :email => author.email)
          end
          
          atom["links"].each do |link|
            e.links << ::Atom::Link.new(:href => link["href"], :title => link["title"], :rel => link["rel"])
          end unless atom["links"].nil?
          ##e.links << ::Atom::Link.new(:href => ".atom", :type => "application/atom+xml", :rel => "self")
          ##e.links << ::Atom::Link.new(:href => ".json", :type => "application/json", :rel => "alternate")
          ##e.links << ::Atom::Link.new(:href => ".dif", :type => "application/dif+xml", :rel => "alternate")
    
          #atom["categories"].each do |category|
          #  e.categories << ::Atom::Category.new(:term => category["term"], :scheme => category["schema"], :label => category["label"])
          #end
          #
          if atom.source?
            source = XML::Reader.string( Gcmd::DifBuilder.new(atom.source.data).build_dif )
            e.source <<::Atom::Source.new(source)
          end
          
          #if atom["source"] and atom["source"]["dif"] and atom["source"]["dif"]["Parameters"]
          #  atom["source"]["dif"]["Parameters"].each do |p|
          #    p.each do |k,v|
          #      e.categories << ::Atom::Category.new(:term => v, :scheme => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/##{k}")
          #    end
          #
          #  end
          #end
          #
          e.published = Time.parse(atom["published"])
          e.updated = Time.parse(atom["updated"])

          #e.rights = atom["rights"]

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
