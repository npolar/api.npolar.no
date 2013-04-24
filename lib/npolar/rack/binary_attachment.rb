require 'yajl/json_gem'
require 'base64'

module Npolar
  module Rack
    class BinaryAttachment < Npolar::Rack::Middleware

      def condition?(request)
        request.request_method == "GET" and request.params.has_key?('attachments') ? true : false
      end
      
      def handle(request)
        response = @app.call(request.env)
        
        # If the resource exists load the attachment and return that as the response
        if response.status == 200
          
          attachments = Yajl::Parser.parse(response.body[0])['_attachments']
        
          attachments.each do |filename, stats|
            
            data = Base64.decode64(stats['data'])
            
            return [
              200,
              {
                'Content-Type' => stats['content_type'],
                'Content-Length' => data.bytesize.to_s,
                'Content-Disposition' => "filename=#{filename}"
              },
              [data]
            ]
          end
          
        end
        
        response
      end
      
    end
  end
end