require "yajl/json_gem"

module Npolar
    module Rack

        class BouvetDataLogger < Npolar::Rack::Middleware

            def condition?(request)
                create?(request)
            end

            def handle(request)
                log.info "@BouvetDataLogger"

                data = JSON.parse(request.body.read)

                if !data.is_a? Array && data.has_key?("head")
                    docs = parse(data)
                    request.env["rack.input"] = StringIO.new(docs.to_json)
                else
                    request.env["rack.input"] = StringIO.new(data.to_json)
                end
                request.env["CONTENT_TYPE"] = "application/json"

                app.call(request.env)
            end

            def create?(request)
                ["PUT", "POST"].include?(request.request_method)
            end

            def parse(data)
                docs = []

                fields = data["head"]["fields"]
                values = data["data"]

                # Check if there is a header for each data value
                if fields.length == values[0]["vals"].length
                    j = 0
                    values.each do |d|
                        doc = {}
                        i = 0
                        # Station is configured with UTC time so we append a Z
                        doc["measured"] = d["time"] + "Z"

                        ## Generate a time based UUID using the sha256 sum as a seed
                        seed = Digest::SHA256.hexdigest doc["measured"]
                        doc["id"] = seed[0,8] + "-" + seed[8,4] + "-" + seed[12,4] + "-" + seed[16,4] + "-" + seed[20,12]

                        fields.each do |f|
                            if f["name"] == "ID"
                                doc["station_id"] = d["vals"][i]
                            else
                                doc[f["name"].downcase] = d["vals"][i]
                            end
                            i += 1
                        end
                        docs[j] = doc
                        j += 1
                    end
                end

                docs
            end
        end
    end
end
