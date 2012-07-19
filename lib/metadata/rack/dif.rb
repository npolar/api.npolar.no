require "atom"
require "gcmd/dif"
require "yajl"

module Metadata

  module Rack

      class Dif < Npolar::Rack::Middleware

        FORMATS = ["atom", "dif", "iso", "xml"] 

        XML_HEADER_HASH = {"Content-Type" => "application/xml; charset=utf-8"}

        def condition? request
          if FORMATS.include? request.format and ["GET","HEAD"].include? request.request_method and request.id?
            true
          else
            false
          end
        end

        def handle(request)

          response = app.call(request.env)

          if response.status < 300

            metadata_dataset = ::Yajl::Parser.parse(response.io)

  
            xml = case request.format
              when "dif", "xml"
                then dif_xml(dif_json(metadata_dataset))
              when "atom"
                then atom_entry(metadata_dataset).to_xml
              when "iso"
                then iso(dif_xml(dif_json(metadata_dataset)))
            end
            [200, XML_HEADER_HASH, [xml]]
          else
            response
          end
        end

        def dif_json(metadata_dataset)
          dif_atom = Metadata::DifAtom.new
          dif_json = dif_atom.dif(metadata_dataset)
        end
  
        def dif_xml(dif_json)
          dif = ::Gcmd::Dif.new(dif_json)
          dif.to_xml
        end


        def atom_entry(metadata_dataset)
          atom = metadata_dataset
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

      def iso(dif)
        tmp = Tempfile.new('dif')
        iso = ""
        begin
          tmp.write dif
          tmp.rewind
          xslfile = File.expand_path(File.dirname(__FILE__)+"/../../../public/xsl/DIF-ISO.xsl")
          iso = `/usr/bin/saxon-xslt #{tmp.path} #{xslfile}`
        ensure
          tmp.close
          tmp.unlink
        end

        iso
      end


    end
  end
end