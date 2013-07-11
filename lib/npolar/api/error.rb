#module Npolar
#  module Api
#    class Error < Hashie::Mash
#    end
#  end
#end
#      def error_hash(status, explanation=nil)
#        {"error"=>{
#          "status"=>status,
#          "reason"=>reason(status),
#          "explanation" => explanation,
#          "uri" => request.url,
#          "id" => request.id,
#          "host"=> `hostname`.chomp,
#          "method" => request.request_method,
#          "level" => level(status),
#          "agent" => request.user_agent,
#          "path" => request.script_name,
#          "format" => request.format,
#          "username" => request.username,
#          "time" => ::DateTime.now.xmlschema,
#          "ip" => request.ip,
#          }
#        }