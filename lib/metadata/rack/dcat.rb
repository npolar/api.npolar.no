require "yajl"
require "uri"
#require "json/ld"

module Metadata

  module Rack
    # Returns [DCAT](http://www.w3.org/TR/vocab-dcat/) RDF graph from upstream Npolar dataset API /dataset
    #
    # Request in [JSON-LD](http://www.w3.org/TR/json-ld/) using either 
    # * https://api.npolar.no/dataset/?q=&format=json&variant=dcat&limit=all (for all datasets)  
    # * https://api.npolar.no/dataset/?q=&format=json&variant=dcat&limit=all&filter-links.rel=data&not-draft=yes&not-progress=planned (for published datasets with a distribution)
    #
    # See also
    # * [DCAT-AP](https://joinup.ec.europa.eu/asset/dcat_application_profile/description)
    # * http://data.opendatasupport.eu:3030/dcat-ap_validator.html
    # * http://data.opendatasupport.eu:3030/samples/sample-json-ld.jsonld
    # * https://joinup.ec.europa.eu/system/files/project/dcat_version_1.1.png
    # * http://difi.github.io/dcat-ap-no/
    # * https://project-open-data.cio.gov/v1.1/schema/
    # * https://project-open-data.cio.gov/v1.1/schema/catalog.json
    # * https://project-open-data.cio.gov/v1.1/schema/dataset.json
    # * [GeoDCAT](http://joinup.ec.europa.eu/site/dcat_application_profile/GeoDCAT-AP/GeoDCAT-AP_2015-07-13_6th_WG_Draft/GeoDCAT-AP_Draft_6_v0.39.pdf)
    # * http://geodcat-ap.semic.eu:8890/api/
    # * https://webgate.ec.europa.eu/CITnet/stash/projects/ODCKAN/repos/iso-19139-to-dcat-ap/browse/documentation/Mappings.md
    #
    # @todo Validate [DCAT-AP-NO](http://difi.github.io/dcat-ap-no/)
    # @todo Support GeoDCAT
    # @todo? Support other RDF serialisations
    class Dcat < Npolar::Rack::Middleware
      
      DCAT_MEDIATYPE_REGEX = /^application\/ld\+json/
      
      FORMATS = ["json"]

      JSON_LD_CONTENT_TYPE = {"Content-Type" => "application/ld+json; charset=utf-8"}
      
      LOC_ISO639_1 = "http://id.loc.gov/vocabulary/iso639-1"
          
      # Trigger on ?q=&format=json&variant=dcat or Accept: application/ld+json
      def condition?(request)
        if "GET" == request.request_method and request["q"] and ( request["variant"] =~ /^((json-)?ld|dcat)$/ or request.content_type =~ DCAT_MEDIATYPE_REGEX) 
          true
        else
          false
        end
      end

      # Only called if #condition? returns true
      def handle(request)
        case request.request_method
          when "GET" then dcat_catalog_response(request)
        end
      end

      # @return [Rack::Response] DCAT Catalog
      def dcat_catalog_response(request)

        response = app.call(request.env)
               
        status = response.is_a?(Array) ? response[0] : response.status

        if status > 300
          response
        else
          
          body = response.is_a?(Array) ? response[2].join() : response.body.to_s
          
          feed_entries = ::Yajl::Parser.parse(body)["feed"]["entries"]
          
          [status, JSON_LD_CONTENT_TYPE, [json_ld_graph(feed_entries).to_json]]
     
        end
      end

      protected
   
      # @return [Hash] JSON-LD graph with @context header
      def json_ld_graph(feed_entries)
        
        { "@context" => dcat_context,
          # "@id" => request.url # hmm: named graph via @id here breaks the opendatasupport validator
          "@graph" => [   
            dcat_Catalog(feed_entries),
            foaf_publisher,
            vcard_contactpoint
          ]
        }
      end
   
      # @return [Hash] Object of @type dcat:Catalog   
      def dcat_Catalog(feed_entries)
        
        # Reverse sort
        feed_entries = feed_entries.select {|d|
          d.key?("id")
        }.sort_by! {|d| d["updated"] }.reverse
        
        dcat_catalog_dataset = feed_entries.map {|d|
          dcat_Dataset(d)
        }
        
        if feed_entries.length > 0
          dc_modified = feed_entries.first["updated"]
        else
          dc_modified = Time.now.utc.xmlschema
        end
              
        {
          # id and type
          "@id" => dcat_catalog_id,
          "@type" => "dcat:Catalog",
          
          # mandatory
          "dcat:dataset" => dcat_catalog_dataset,
          "dc:description" => dcat_catalog_dc_description,
          "dc:publisher" => dc_publisher_id,
          "dc:title" => dcat_catalog_dc_title,
          
          #recommended
          "foaf:homepage" => dcat_catalog_foaf_homepage,
          "dc:language" => "#{LOC_ISO639_1}/en",
          "dc:license" => dcat_catalog_dc_license_id, # Licence of the catalog
          "dc:issued" => dcat_catalog_dc_issued,
          #"dcat:themeTaxonomy" => [{ "@id" => "id"}],
          "dc:modified" => dc_modified
     
          # optional
          # dc:hasPart
          # dc:isPart
          # dcat:record
          # dc:rights => dcat_catalog_dc_rights,
          # dc:spatial
        }
      end
      
      # @return [Hash] Object of @type dcat:Dataset     
      def dcat_Dataset(npolar_dataset)
        d = Metadata::Dataset.new(npolar_dataset)
        if d.title.nil?
          d.title="" 
        end

        dataset = {
          
          # type and id
          "@id" => Dataset::BASE + d.id,
          "@type" => "dcat:Dataset",
          
          # mandatory (DCAT-AP)
          "dc:title" => d.title,
          "dc:description" => d.summary || d.title,
          
          # recommended
          # "dcat:contactPoint" => { "@id" => "http://data.npolar.no" },
          # dcat:distribution is added further down
          "dcat:keyword" => (d.tags || []),
          "dc:publisher" => dc_publisher_id,
          # "dcat:theme" => [] @todo
          
          # optional
          "dc:identifier" => d.id,
          "dcat:landingPage" => "https://data.npolar.no/#{d.id}",
          "dc:issued" => d.released || d.created,
          "dc:modified" => d.updated
        }
          
        # @todo ISO topic => dct:subject (GeoDCAT)
        # @todo "accessLevel" => d.restricted.nil? ? "public" : "restricted",
        # @todo "conformsTo"
        
        # Add distribution for all data links
        data_links = d["links"].select {|l| l["rel"] == "data"}
        if data_links.size > 0
          dataset["dcat:distribution"] = data_links.map {|link| dcat_distribution(link,d) }
        end
        
        dataset
      end
      
      def dcat_catalog_id        
        request.url
      end
      
      def dcat_catalog_dc_description
        uri = "https://data.npolar.no/dataset/ae1a945b-6b91-42c0-86e6-4657b4b6ec3c"
        [ { "@language" => "en",
            "@value" => "Datasets published by the Norwegian Polar Institute. See #{uri} for alternative metadata formats and access protocols" 
          },
          { "@language" => "nb",
            "@value" => "Datasett publisert av Norsk Polarinstitutt. Se #{uri} for mer informasjon" 
          },
          { "@language" => "nn",
            "@value" => "Datasett publisert av Norsk Polarinstitutt. Sjå #{uri} for meir informasjon" 
          }
        ]
      end
      
      def dc_publisher_id
        "http://npolar.no"
      end
      
      def dcat_catalog_dc_issued
        "2008-01-14T12:00:00Z"
      end
      
      def dcat_catalog_dc_license_id
         "http://creativecommons.org/licenses/by/4.0/"
      end
      
      #def dcat_catalog_dc_rights
      #  [ { "@language" => "en",
      #      "@value" => "" 
      #    },
      #    { "@language" => "nb",
      #      "@value" => "" 
      #    },
      #    { "@language" => "nn",
      #      "@value" => "" 
      #    }
      #  ]
      #end
      
      def dcat_catalog_dc_title
        [
          {"@language" => "en", "@value" => "Dataset Catalogue of the Norwegian Polar Institute" },
          {"@language" => "nb", "@value" => "Datasett frå Norsk Polarinstitutt" },
          {"@language" => "nn", "@value" => "Datasett fra Norsk Polarinstitutt" },
        ]
      end
 
      def dcat_catalog_foaf_homepage
        "https://data.npolar.no"
      end
      
      def dcat_context
        JSON.parse %({
          "dcat": "http://www.w3.org/ns/dcat#",
          "dc": "http://purl.org/dc/terms/",
          "foaf": "http://xmlns.com/foaf/0.1/",
          "vcard": "http://www.w3.org/TR/vcard-rdf/",
          "dcat:accessURL": {
             "@type": "@id"
          },
          "dcat:landingPage": {
             "@type": "@id"
          },
          "dc:license": {
             "@type": "@id"
          },
          "dc:publisher": {
             "@type": "@id"
          },
          "dc:issued": {
            "@type": "http://www.w3.org/2001/XMLSchema#date"
          },
          "dc:modified": {
            "@type": "http://www.w3.org/2001/XMLSchema#date"
          }
        })
      end

      # @return [Hash] Object of type dcat:Distribution
      def dcat_distribution(link,d)
        {
          "@type" => "dcat:Distribution",
          "dcat:accessURL" => link.href,
          "dcat:mediaType" => link.type,
          # format if mediaType is dubious
          # description
          "dc:title" => link.title,
          "dc:license" => d.licences.first.gsub(/\/by\/3\.0\/no\//, "/by/4.0/"),
          "dcat:byteSize" => (link["length"] or -1),
          "dc:issued" => (d.released or d.created),
          "dc:modified" => (link.modified or d.updated)
        }
      end
      
      # @return [Hash] Object of type foaf:Agent
      def foaf_publisher
        { "@id" => dc_publisher_id,
          "@type" => "foaf:Agent",
          "foaf:name" => [
            { "@language" => "en",
              "@value" => "Norwegian Polar Institute" 
            },
            { "@language" => "nb",
              "@value" => "Norsk Polarinstitutt" 
            },
            { "@language" => "nn",
              "@value" => "Norsk Polarinstitutt" 
            }
          ],
          "foaf:homepage" => "https://npolar.no"
        }
      end
      
      def vcard_contactpoint
        JSON.parse %({
          "@id": "http://data.npolar.no",
          "@type": "vcard:Organization",
          "vcard:fn": "Norwegian Polar Data Centre",
          "vcard:hasEmail": {
            "@id": "mailto:data@npolar.no"
          }
        })
      end
      
    end
  end
end