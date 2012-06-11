require "atom"
require "gcmd/dif"


module Api
  module Metadata
    class DatasetCollection < Api::Collection

      def default_format
        "json"
      end
    
      # accepts
      # "json" "xml" "dif"

      def formats
        ["", "atom", "dif", "iso", "json", "source", "text", "xml"]
      end

      def get(id, headers = {})
        response = super

        if response[0] < 300

          if /^(json||source|raw)$/ =~ format.to_s # JSON, *blank*, source or raw format?
            # noop => just return the response

          elsif /^atom$/ =~ format.to_s

            json = JSON.parse(response[2])
            response[1]["Content-Type"]="application/xml"

            #dif_atom = ::Metadata::DifAtom.new
      
            response[2] = atom_entry(json).to_xml

          elsif /^(dif|xml|iso)$/ =~ format.to_s
            json = JSON.parse(response[2])

            xml = dif_xml(json)

            response[1]["Content-Type"] = "application/xml"
            response[2] = xml

            if /^iso$/ =~ format.to_s
              response[2] = iso(dif_xml(xml))
            end

          else
            # Unacceptable format
            response[0] = 406 # HTTP/1.1 406 Not Acceptable
            # But we still return the body to be nice :)
          end

        end
        response

      end

      # Support PUTting DIF XML
      def put(id, data, headers)

        if /^(dif|xml)$/ =~ format.to_s
          dif = ::Gcmd::Dif.new
          dif_hash = dif.load_xml(data)

          dif_atom = ::Metadata::DifAtom.new
          atom_hash = dif_atom.atom_from_dif(dif_hash)
          data = atom_hash.to_json

          
          headers["CONTENT_TYPE"] = "application/json"
          headers["CONTENT_LENGTH"] = data.bytesize.to_s          
          headers["rack.input"] = ::Rack::Lint::InputWrapper.new( StringIO.new( data ) )

        end
        super
      end

      # support multiple documents

      def post(data, headers)

        put("dummy4", data, headers)
      end

      def atom_entry(atom)
        entry = ::Atom::Entry.new do |e|
          e.id = "urn:uuid:#{atom["id"]}"

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

      ##
      # DIF Hash from dataset as Atom-like Hash
      #
      #def dif_from_atom(atom)
      #  {
      #    "Entry_ID" => atom["id"],
      #    "Entry_Title" => atom["title"],
      #    "Personnel" => personnel_from_contributors(atom["contributors"]),
      #  }
      #end

      def dif_xml(dif_json)
        dif = ::Gcmd::Dif.new(dif_json)
        dif.to_xml
      end

      def iso(dif)
        tmp = Tempfile.new('dif')
        iso = ""
        begin
          tmp.write dif
          tmp.rewind
          xslfile = File.expand_path(File.dirname(__FILE__)+"/../../public/xsl/DIF-ISO.xsl")
          iso = `/usr/bin/saxon-xslt #{tmp.path} #{xslfile}`
        ensure
          tmp.close
          tmp.unlink
        end

        iso
      end

      # extract bounding box()
      #[{"Southernmost_Latitude":"78.9651307","Northernmost_Latitude":"78.9651307","Westernmost_Longitude":"11.8569355","Easternmost_Longitude":"11.8569355"},{"Southernmost_Latitude":"79.033295","Northernmost_Latitude":"79.033295","Westernmost_Longitude":"10.8120855","Easternmost_Longitude":"10.8120855"},{"Southernmost_Latitude":"78.2494325","Northernmost_Latitude":"78.2494325","Westernmost_Longitude":"14.78042","Easternmost_Longitude":"14.78042"},{"Southernmost_Latitude":"78.9947663","Northernmost_Latitude":"78.9947663","Westernmost_Longitude":"10.1573606","Easternmost_Longitude":"10.1573606"},{"Southernmost_Latitude":"79.1225453","Northernmost_Latitude":"79.1225453","Westernmost_Longitude":"11.6797199","Easternmost_Longitude":"11.6797199"},{"Southernmost_Latitude":"78.449295","Northernmost_Latitude":"78.449295","Westernmost_Longitude":"17.3396488","Easternmost_Longitude":"17.3396488"}]

      
    def search
      response = storage.feed
      response
    end

    def rel_from_dif_url_content_type(u)
      if u.is_a? String
        type = u  
      else
        type = u["Type"]
      end
      ::Metadata::DifAtom.rel(type)

    end

    end
  end
end
