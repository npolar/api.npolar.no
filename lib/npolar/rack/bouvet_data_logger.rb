module Npolar
    module Rack

        class BouvetDataLogger < Npolar::Rack::Middleware

            def condition?(request)
                create?(request)
            end

            def handle(request)
                log.info "@BouvetDataLogger"

                data = request.body.read
                docs = parse(data)

                request.env["rack.input"] = docs
                request.env["CONTENT_TYPE"] = "application/json"

                app.call(request.env)
            end

            def create?(request)
                ["PUT", "POST"].include?(request.request_method)
            end

            def parse(data)
                docs = []

                fields = data[:head][:fields]
                data = data[:data]

                # Check if there is a header for each data value
                if fields.length == data[0][:vals].length
                    data.with_index do |d,j|
                        doc = {}
                        doc[:measured] = data[:time]

                        ## Generate a time based UUID using the sha256 sum as a seed
                        seed = Digest::Sha256.hexdigest doc[:measured]
                        doc[:id] = seed[0,8] + "-" + seed[8,4] + "-" + seed[12,4] + "-" + seed[16,4] + "-" + seed[20,12]

                        fields.with_index do |f,i|
                            doc[f] = d[:vals][i]
                        end
                        docs[j] = doc
                    end
                end

                docs
            end
        end
    end
end
