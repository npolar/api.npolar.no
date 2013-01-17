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

          # store diff of new vs. old
	  diff = HashDiff.diff(Yajl::Parser.parse(response[2]), data)

	  log.debug "#{request.request_method} on #{data['_id']}" 
          log.debug "user = #{request.username}"
	  log.debug "diff = #{diff}\n"
         
          post_hash = {
            :data_id => data['_id'],
            :db => config[:data_storage].alias,
            :diff => diff,
	    :username => request.username,
	  }

	  response = app.call(request.env)

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
