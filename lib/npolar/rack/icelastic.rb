module Npolar
  module Rack

    # [Functionality]
    #   Icelastic is a middleware that exposes elasticsearch on a RACK endpoint.
    #   On GET requests it translates request parameters into the correct elasticsearch
    #   syntax and uses them to query the configured elasticsearch index.
    #
    # [Authors]
    #   - Ruben Dens
    #
    # [Links]
    #   @see http://www.elasticsearch.org/guide/reference/api/search/ Elasticsearch search Documentation

    class Icelastic < Npolar::Rack::Middleware

      attr_accessor :env

      CONFIG = {
        :uri => 'http://localhost:9200/',
        :index => 'global',
        :type => nil,
        :fields => nil,
        :start => 0,
        :limit => 25,
        :facets => nil,
        :date_facets => nil,
        :filters => nil,
        :sort => nil
      }

      def condition?(request)
        (['GET','HEAD'].include?(request.request_method) and !request.params.select{|k,v| k.match(/q(\-.*)?/)}.empty?) || ['PUT','POST','DELETE'].include?(request.request_method)
      end

      def handle(request)

        # New client instance
        client = Npolar::ElasticSearch::Client.new(request, config)

        # READ
        if ['GET', 'HEAD'].include?(request.request_method) and !request.params.select{|k,v| k.match(/q(\-.*)?/)}.empty?
          response = client.search

          unless response.status == 200
            response =  Rack::Response.new(error_hash(response.status, response.body).to_json, response.status, {"Content-Type" => "application/json; charset=utf8"})
          end

          response

        # CREATE & UPDATE
        elsif ['PUT', 'POST'].include?(request.request_method)
          docs = JSON.parse( request.body.read )
          request.body.rewind

          response = app.call(request.env)

          if [200, 201].include?( response.status ) && request.request_method == 'POST'

            body = JSON.parse( response.body.first )

            puts body

            if body['response'] && body['response'].has_key?("ids")
              body['response']['ids'].each_with_index do |id, i|
                docs[i]["id"] ||= id
              end
            elsif body.has_key?("id")
              docs["id"] = body["id"]
            end

            client.index(docs)
          end

          response

        # DELETE
        elsif ['DELETE'].include?(request.request_method)
          id = request.env['PATH_INFO'].gsub(/\//,'')

          response = app.call(request.env)

          if response.status == 200
            client.delete(id)
          end

          response
        end

      end

    end
  end
end
