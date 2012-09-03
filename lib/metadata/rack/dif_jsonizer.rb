require "atom"
require "gcmd/dif_builder"
require "gcmd/hash_builder"
require "yajl"
require "uuidtools"

module Metadata

  module Rack

    class DifJsonizer < Npolar::Rack::Middleware

      FORMATS = ["atom", "dif", "iso", "xml"]

      ACCEPTS = ["xml", "dif"]

      XML_HEADER_HASH = {"Content-Type" => "application/xml; charset=utf-8"}

      JSON_HEADER_HASH = {"Content-Type" => "application/json; charset=utf-8"}
      
      NAMESPACE = "http://data.npolar.no/"
      
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

      def dif_save(request)
        xml = request.body.read
        builder = ::Gcmd::HashBuilder.new( xml )
        difs = builder.build_hash_documents
        j = []
        difs.each do | dif_hash |
          dif_atom = ::Metadata::DifAtom.new
          atom_hash = dif_atom.atom_from_dif(dif_hash)
          atom_hash["_id"] = namespaced_uuid( atom_hash["id"] )
          j << atom_hash
        end

        json = j.to_json

        request.env["CONTENT_TYPE"] = "application/json"
        request.env["CONTENT_LENGTH"] = json.bytesize.to_s
        request.env["rack.input"] = ::Rack::Lint::InputWrapper.new( StringIO.new( json ) )
        app.call(request.env)
      end

      def dif_from_json(request)

        response = app.call(request.env)

        if response.status < 300

          metadata_dataset = ::Yajl::Parser.parse(response.io)

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
        dif_atom = Metadata::DifAtom.new
        dif_json = dif_atom.dif(metadata_dataset)
      end

      def dif_xml(dif_json)
        builder = ::Gcmd::DifBuilder.new( dif_json )
        builder.build_dif
      end

      def atom_entry(metadata_dataset)
        atom = metadata_dataset
        entry = ::Atom::Entry.new do |e|
          e.id = atom["dif:Entry_ID"] || "urn:uuid:#{atom["id"]}"

          e.title = atom["title"]
          e.summary = atom["summary"]

          e.authors << ::Atom::Person.new(:name => 'John Doe')

          atom["contributors"].each do |c|
            e.contributors << ::Atom::Person.new(:name => c["first_name"]+" "+c["last_name"], :email => c["email"], :uri => c["uri"])
          end

          atom["links"].each do |link|
            e.links << ::Atom::Link.new(:href => link["href"], :title => link["title"], :rel => link["rel"])
          end
          #e.links << ::Atom::Link.new(:href => ".atom", :type => "application/atom+xml", :rel => "self")
          #e.links << ::Atom::Link.new(:href => ".json", :type => "application/json", :rel => "alternate")
          #e.links << ::Atom::Link.new(:href => ".dif", :type => "application/dif+xml", :rel => "alternate")

          atom["categories"].each do |category|
            e.categories << ::Atom::Category.new(:term => category["term"], :scheme => category["scheme"], :label => category["label"])
          end

          if atom["source"] and atom["source"]["dif"] and atom["source"]["dif"]["Parameters"]
            atom["source"]["dif"]["Parameters"].each do |p|
              p.each do |k,v|
                e.categories << ::Atom::Category.new(:term => v, :scheme => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/##{k}")
              end

            end
          end

          e.published = Time.parse(atom["published"])
          e.updated = Time.parse(atom["updated"])

         # e.rights = atom["rights"]

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