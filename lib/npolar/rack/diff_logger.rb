# encoding: utf-8

require 'hashdiff'
require 'json-schema'

module Npolar
  module Rack
    class DiffLogger < Npolar::Rack::Middleware
      
      CONFIG = {
        :data_storage => nil,
        :diff_storage => nil,
      }
        
      def condition?(request)
        return true if ["PUT", "DELETE"].include?(request.request_method)
        false
      end
      
      def handle(request)
        begin
          data = Yajl::Parser.parse(request.body.read)
          request.body.rewind

          # try to find record by id
          response = config[:data_storage].get(data['_id'])
          if response[0] == 404
            raise "record not found"
          end

          # create diff of new vs. old
          diff = HashDiff.diff(Yajl::Parser.parse(response[2]), data)

          log.debug "#{request.request_method} on #{data['_id']}" 
          log.debug "user = #{request.username}"
          log.debug "diff = #{diff}\n"

          # parse out workspace and collection from URI
          uri = request.env["REQUEST_URI"].sub(/^\//, '')
          uri_toks = uri.split("/")
          uri_toks.pop()
          if uri_toks.length != 2
            raise "URI must contain workspace and collection"
          end
          workspace = uri_toks[0]
          collection = uri_toks[1]

          post_hash = {
            :data_id => data['_id'],
            :workspace => workspace,
            :collection => collection,
            :diff => diff,
            :username => request.username,
          }

          # pass req to next layer and check for good response
          response = app.call(request.env)

          # if OK, save the diff
          if [200, 201].include?(response.status)
            config[:diff_storage].post(post_hash.to_json)
          end

          return response

        rescue Exception => e
          [404, {"Content-Type" => "application/json"}, e.message]
        end        
      end

    end
  end
end