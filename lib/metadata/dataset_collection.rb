require "atom"

module Api
  module Metadata
    class DatasetCollection < Api::Collection

      def get(id, headers = {})
        super

        if @response[0] < 400

          if /^(raw)$/ =~ @format.to_s
            # noop
          elsif /^(json||source)$/ =~ @format.to_s # JSON, *blank*,or source format?
            json = JSON.parse(@response[2])
            # Check: Are we dealing with DIF JSON?
            if json["Entry_ID"] and json["Entry_Title"]
              atom = atom_from_dif(json)
              atom.delete "source" unless @format =~ /source/

              @response[2] = atom.to_json

            end

          elsif /^atom$/ =~ @format.to_s

            json = JSON.parse(@response[2])
            @response[1]["Content-Type"]="application/xml"
            @response[2] = atom_entry(atom_from_dif(json)).to_xml

          elsif /^(dif|xml)$/ =~ @format.to_s

            xml = dif_xml(@response[2])
            @response[1]["Content-Type"] = "application/xml"
            @response[2] = xml

          elsif /^iso$/ =~ @format.to_s

            @response[1]["Content-Type"] = "application/xml"

            @response[2] = iso(dif_xml(@response[2]))

          else
            # Unacceptable @format
            @response[0] = 406 # HTTP/1.1 406 Not Acceptable
            # But we still return the body to be nice :)
          end

        end

        @response[1]["Content-Length"] = @response[2].bytesize.to_s
        @response

      end

      # Support PUTting DIF XML
      def put(id, data, headers)
        before_request("PUT", id, headers)
        if /^(dif|xml)$/ =~ @format.to_s
          dif = Gcmd::Dif.new
          json = dif.load_xml(data)
          data = json
        end
        super
      end

      # support multiple documents

      def post
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
            e.categories << ::Atom::Category.new(:term => category["term"], :scheme => category["scheme"])
          end

          if atom["source"] and atom["source"]["dif"]
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
      def dif_from_atom(atom)
        {
          "Entry_ID" => atom["id"],
          "Entry_Title" => atom["title"],
          "Personnel" => personnel_from_contributors(atom["contributors"]),
        }
      end

      def dif_xml(dif_json)
        dif = Gcmd::Dif.new(dif_json)
        dif.to_xml
      end

      ##
      # Atom-like Hash from DIF Hash
      #
      def atom_from_dif(dif)
        atom = {
          #"dif" => dif,
          #"author" => extract_author #{ "name" => "Norwegian Polar Institute", "uri" => "http://data.npolar.no", "email" => ""},
          "contributors" => extract_contributors(dif["Personnel"]),
          "summary" => dif["Summary"]["Abstract"],
          "id" => dif["id"].nil? ? dif["_id"] : dif["id"],
          "links" => extract_links(dif),
          "title" => dif["Entry_Title"],
          "published" => dif["DIF_Creation_Date"]+"T12:00:00Z",
          "updated" => dif["Last_DIF_Revision_Date"]+"T12:00:00Z",
          "rights" => dif["Use_Constraints"],
          "draft" => "no"
        }

        if dif["Private"] == "True"
          atom["draft"] = "yes"
        end

        unless dif["Data_Center"].nil?
          dif["Data_Center"].each do | data_center |
            url = data_center["Data_Center_URL"]
            if url =~ /http\:\/\/(www\.)?npolar\.no/
              url = "http://data.npolar.no"
            end

            atom["links"] << { "href" => url, "rel" => "http://api.npolar.no/atom/category#datacenter" }
          end
        end
        #Data_Center => link@rel=htpp...#Data_Center?

        unless dif["Spatial_Coverage"].nil?
          atom["north"] = dif["Spatial_Coverage"].first["Northernmost_Latitude"],
          atom["east"] = dif["Spatial_Coverage"].first["Easternmost_Longitude"],
          atom["west"] = dif["Spatial_Coverage"].first["Westernmost_Longitude"],
          atom["south"] = dif["Spatial_Coverage"].first["Southernmost_Latitude"]
        end

        # << add contributors from Data Center
        atom["categories"] = []
        
        unless dif["ISO_Topic_Category"].nil?
          dif["ISO_Topic_Category"].each do |isotc|
            atom["categories"] << { "term" => isotc, "scheme" => "http://isotc211.org" }
          end
        end

        unless dif["Keyword"].nil?
          dif["Keyword"].each do | keyword |
            atom["categories"] << { "term" => keyword }
          end
        end

        # Delete DIF data that is mapped above
        dif.delete "Personnel"
        dif.delete "Related_URL"
        dif.delete "Use_Constraints"
        dif.delete "DIF_Creation_Date"
        dif.delete "Last_DIF_Revision_Date"
        dif.delete "ISO_Topic_Category"
        dif.delete dif["Summary"]["Abstract"]
        if dif["Spatial_Coverage"] and dif["Spatial_Coverage"].size == 1
          dif.delete "Spatial_Coverage"
        end


        #"Metadata_Version":"9.8.2","Originating_Metadata_Node":"NPI/RiS","Data_Set_Language":["English"],"IDN_Node":[{"Short_Name":"ARCTIC/NO"},{"Short_Name":"ARCTIC"}]


        atom["source"] = { "dif" => dif }
        atom
      end

      # Beware of multiple roles, emails...
      def extract_contributors(personnel)

        return [] if personnel.nil?

        personnel.map { |p| {
            "email" => p["Email"].nil? ? "" : p["Email"],
            "first_name" =>  "#{p["First_Name"]} #{p["Middle_Name"]}".gsub(/\s+$/, ""),
            "last_name" =>  p["Last_Name"],
            "role" => p["Role"],
          }
        }
      end

      def extract_links(dif)
        return [] if dif["Related_URL"].nil?
        dif["Related_URL"].map { |r| extract_link_or_links(r) }.flatten
      end

      # A DIF Related_URL may contain many URLs
      def extract_link_or_links(r)
        links = []
        if r["URL"].is_a? String
          url = r["URL"]
          r["URL"] = [url]
        end
        r["URL"].each do | url |
          links << {
            "title" => r["Description"],
            "href" => r["URL"].first,
            "rel" => "related",
            "type" => nil,
            "dif:type" => r["URL_Content_Type"]["Type"],
            "dif:subtype" => r["URL_Content_Type"]["Subtype"],
          }
        end
        links

      end

      def iso(dif)
        tmp = Tempfile.new('dif')
        iso = ""
        begin
          tmp.write dif
          tmp.rewind
          iso = `saxon-xslt #{tmp.path} /home/ch/github.com/api.npolar.no/public/xsl/DIF-ISO.xsl`
        ensure
          tmp.close
          tmp.unlink   # deletes the temp file
        end

        iso
      end

      # extract bounding box()
      #[{"Southernmost_Latitude":"78.9651307","Northernmost_Latitude":"78.9651307","Westernmost_Longitude":"11.8569355","Easternmost_Longitude":"11.8569355"},{"Southernmost_Latitude":"79.033295","Northernmost_Latitude":"79.033295","Westernmost_Longitude":"10.8120855","Easternmost_Longitude":"10.8120855"},{"Southernmost_Latitude":"78.2494325","Northernmost_Latitude":"78.2494325","Westernmost_Longitude":"14.78042","Easternmost_Longitude":"14.78042"},{"Southernmost_Latitude":"78.9947663","Northernmost_Latitude":"78.9947663","Westernmost_Longitude":"10.1573606","Easternmost_Longitude":"10.1573606"},{"Southernmost_Latitude":"79.1225453","Northernmost_Latitude":"79.1225453","Westernmost_Longitude":"11.6797199","Easternmost_Longitude":"11.6797199"},{"Southernmost_Latitude":"78.449295","Northernmost_Latitude":"78.449295","Westernmost_Longitude":"17.3396488","Easternmost_Longitude":"17.3396488"}]



    end
  end
end
