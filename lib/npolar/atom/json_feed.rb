module Npolar
  module Atom
    class JsonFeed

      attr_accessor :entries 

      def build


        # on save
        entries.each do | entry |
          entry["id"] = entry["_id"] # if not exists?
          entry.delete "_id"
          entry["link"] = { "href" => entry["code"], "rel" => "edit"} # if not exists?
        end

        data_header = Api::Atom::Feed.header
        data_header["opensearch:totalResults"] = entries.size

        feed = {}
        feed["header"] = data_header
        feed["entry"] = entries

        feed_json = {"feed" => feed }.to_json

        headers = response.headers
        headers["Content-Type"] = "application/json"
        headers["Content-Lenght"] = feed_json.bytesize.to_s

        [200, headers, feed_json]
        # 304 403 200
      end

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
          "sru:numberOfRecords" => 0,
          "title" => "",
          "base" => "",
          "links" => [
            { "rel" => "self", "href" => "" },
            { "rel" => "first", "href" => "" },
            { "rel" => "previous", "href" => ""},
            { "rel" => "next", "href" => "" },
            { "rel" => "last", "href" => "" }
        ],
        "id" => "urn:uuid:a6852153-dc12-4cd9-b3e0-f9ff2ed7f0b3",
        "author" => {

        } }
      end
    end
  end
end
