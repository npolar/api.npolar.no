require 'yajl/json_gem'
require 'base64'

module Npolar
  module Rack
    class BinaryAttachment < Npolar::Rack::Middleware
      
      def condition?(request)
        return true if request.request_method == "GET" and request.params.has_key?('attachments')
        false
      end
      
      def handle(request)
        puts "^_^ + "*3
        response = @app.call(request.env)
        
        if response.status == 200
          
          attachments = Yajl::Parser.parse(response.body[0])['_attachments']
        
          attachments.each do |filename, stats|
            return [200, {'Content-Type' => stats['content_type'], "Content-Disposition" => "filename=#{filename}"}, [Base64.decode64(stats['data'])]]
          end
          
        end
        
        response
      end
      
    end
  end
end