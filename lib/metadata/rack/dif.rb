require "atom"
require "gcmd/dif_builder"
require "gcmd/hash_builder"
require "yajl"

module Metadata

  module Rack

    class Dif < Npolar::Rack::Middleware

      FORMATS = ["atom", "dif", "iso", "xml"]

      ACCEPTS = ["xml", "dif"]

      XML_HEADER_HASH = {"Content-Type" => "application/xml; charset=utf-8"}

      JSON_HEADER_HASH = {"Content-Type" => "application/json; charset=utf-8"}
      
      XSL = "DIF-ISO-3.1.xsl"

      def condition? request
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
          j << atom_hash
        end
        if 1 == j.size
          j = j[0]
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
            dif = ::Gcmd::Dif.new
            dif.load_xml xml
            report = dif.validate_xml
            [200, JSON_HEADER_HASH, [report.to_json]]
          else
            [200, XML_HEADER_HASH, [xml]]
          end

        else
          response
        end
      end

      protected

      def dif_json(metadata_dataset)
        dif_atom = Metadata::DifAtom.new
        dif_json = dif_atom.dif(metadata_dataset)
      end

      def dif_xml(dif_json)
        builder = ::Gcmd::DifBuilder.new
        builder.build_dif( dif_json )
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