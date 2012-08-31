module Api
  module Atom
    class Feed


# http://nurture.nature.com/opensearch/
# http://nurture.nature.com/opensearch/demo/solar2-json.txt
#         "opensearch:startIndex": 12,
#         "opensearch:itemsPerPage": 2,
#         "opensearch:Query": {
#             "opensearch:role": "request",
#             "opensearch:searchTerms": "cql.keywords adj \"solar eclipse\""
#         },
#
#         "sru:numberOfRecords": 1509,
#         "sru:resultSetId": "a6852153-dc12-4cd9-b3e0-f9ff2ed7f0b3",
#         "dc:publisher": "Nature Publishing Group",
#         "dc:language": "en",
#         "dc:rights": "© 2009 Nature Publication Group",

      def self.header
      {
          "opensearch:totalResults" => 0,
          "title" => "",
          "base" => "",
          "links" => [
            { "rel" => "self",
                "href" => ""
            },
            {
                "rel" => "first",
                "href" => ""
            },
            {
                "rel" => "previous",
                "href" => ""
            },
            {
                "rel" => "next",
                "href" => ""
            },

            {
                "rel" => "last",
                "href" => ""
            }
        ],
        "id" => "urn:uuid:a6852153-dc12-4cd9-b3e0-f9ff2ed7f0b3",
        "author" => {

        } }
      end
    end
  end
end
