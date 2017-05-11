module Metadata

  class DataciteXml

    DATACITE_TEST_PREFIX = "10.5072"

    DATACITE_NAMESPACE = "http://datacite.org/schema/kernel-4"

    NPOLAR_DOI_PREFIX = "10.21334"

    def self.doi(dataset,suffix=nil,prefix=DATACITE_TEST_PREFIX)

      suffix = suffix.nil? ? dataset.id : suffix

      if dataset.doi =~ /^10[.][0-9]+\/.+/
        dataset.doi
      else
        "#{prefix}/#{suffix}"
      end
    end

    def self.kernel(dataset,doi)
      publicationYear = (!dataset.released.nil? and dataset.released =~ /^\d{4}-/) ? dataset.released.split("-").first : dataset.created.split("-").first
      publisher = (dataset.organisations||[]).select {|o| o.roles.include? "publisher"}.map {|p| p.id||p.name }.join(", ")
      creators = (dataset.people||[]).select {|p| p.roles.include? "author"}.map {|p| {
          creatorName: "#{p.last_name}, #{p.first_name}",
          givenName: p.first_name,
          familyName: p.last_name
        }
      }

      if creators.none?

        creators = dataset.organisations.select {|o| o.roles.include? "author"}.map {|o| {
          creatorName: "#{o.name} (#{o.id})"
        }
      }

        if creators.none?
          raise "No authors: #{dataset.id}"
        end
      end


      return Nokogiri::XML::Builder.new(:encoding => "UTF-8") do | xml |

        xml.resource(:xmlns => DATACITE_NAMESPACE,
          "xsi:schemaLocation" => "#{DATACITE_NAMESPACE} #{'http://schema.datacite.org/meta/kernel-4/metadata.xsd'}",
          "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance") {
          xml.identifier({identifierType: "DOI"}, doi)

          xml.creators {
            creators.each do |p|
              xml.creator {
                xml.creatorName p[:creatorName]
                #xml.givenName p.first_name
                #xml.familyName p.last_name
                #xml.affiliation p.organisation||(p.email||"").split("@").last

              }
            end
          }

          xml.titles {
            xml.title({"xml:lang" => "en"}, dataset.title)
          }

          xml.publisher publisher
          xml.publicationYear publicationYear

          xml.dates {
            xml.date({dateType: "Available"}, dataset.released||nil)
            xml.date({dateType: "Updated"}, dataset.updated)
            xml.date({dateType: "Created"}, dataset.created)
          }

          xml.resourceType({resourceTypeGeneral: "Dataset"}, "Dataset")

          xml.alternateIdentifiers {
            xml.alternateIdentifier({alternateIdentifierType: "revision"}, "https://api.npolar.no/dataset/#{dataset.id}?rev=#{dataset._rev}")
          }

          xml.relatedIdentifiers {
            xml.relatedIdentifier({relatedIdentifierType: "URL", relationType: "IsDocumentedBy"}, "https://data.npolar.no/dataset/#{dataset.id}")
          }

          if dataset.licences.any? {|l| l =~ /creativecommons\.org\/licenses\/by\// }
            license="http://creativecommons.org/licenses/by/4.0/"
          elsif dataset.licences.any?
            license=dataset.licences[0]
          else
            license=nil
          end

          if not license.nil?
            xml.rightsList {
              xml.rights({ rightsURI: license }, license)
            }
          end

          xml.descriptions {
            xml.description({descriptionType: "Abstract", "xml:lang" => "en"}, dataset.summary)
          }

          xml.subjects {
            dataset.tags||[].each do |tag|
              xml.subject tag
            end
          }
        }
      end

    end

  end
end