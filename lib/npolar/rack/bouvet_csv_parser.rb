#encoding: utf-8
require 'csv'

module Npolar
  module Rack

    class BouvetCsvParser < Npolar::Rack::Middleware

      def condition?(request)
        create?(request)
      end

      def handle(request)
        log.info "@BouvetCsvParser: parsing input"
        t0 = Time.now
        data = request.body.read

        docs = parse(data)
        request.env["rack.input"] = StringIO.new(docs.to_json)
        request.env['CONTENT_TYPE'] = "application/json"

        log.info "@BouvetCsvParser: Input parsed in #{Time.now - t0}"
        pp docs
        app.call(request.env)
      end

      def create?(request)
        ["PUT", "POST"].include?(request.request_method)
      end

      # parse text data, returns array of docs
      def parse(data)
        docs = []
        rows = CSV::parse(data)
        if rows.length > 4
          # TODO/FIXME: get Tor Ivan to make a proper csv header
          header = rows[1]

          rows[4, rows.length].each do |row|
            doc = Hash[header.zip(row)]

            doc.each do |key, val|

              # try for int, if that fails, go for float, else string
              begin
                doc[key] = Integer(val)
              rescue ArgumentError
                begin
                  doc[key] = Float(val)
                rescue ArgumentError
                end
              end

            end

            # make the timestamp ours
            toks = doc.delete("TIMESTAMP").split()
            doc["measured"] = toks[0]+"T"+toks[1]+"Z"

            # generate the sha256 digest based on the measurement time and use it as
            # a namespaced UUID seed to prevent duplicate data from entering the database.
            seed = Digest::SHA256.hexdigest doc["measured"]
            doc["id"] = seed[0,8] + "-" + seed[8,4] + "-" + seed[12,4] + "-" + seed[16,4] + "-" + seed[20,12]

            # point to our schema
            doc["schema"] = "http://api.npolar.no/schema/weather-bouvet-1.0-rc1"
            docs << doc
          end
        end

        docs
      end
    end
  end
end
