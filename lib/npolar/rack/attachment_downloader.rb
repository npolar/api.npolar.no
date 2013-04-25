require 'yajl/json_gem'
require 'base64'

module Npolar
  
  # [Description]
  #   This middleware is built to accomodate binary attachment downloads. To prevent us from having
  #   to load the entire attachment into the application we repackage the request as a redirect and
  #   have Nginx serve the data directly from the database. The middleware triggers on requests with
  #   the attachment parameter followed by a filename ?attachment=myfile.txt
  
  module Rack
    class AttachmentDownloader < Npolar::Rack::Middleware
      
      CONFIG = {
        :database => nil
      }
      
      def condition?(request)
        request.request_method == "GET" and request.params.has_key?('attachment') ? true : false
      end
      
      def handle(request)
        filename = request.params['attachment']
        
        # Respond with the filename and a redirect for Nginx to use and serve the download
        
        [
          200,
          {
            'Content-Disposition' => "inline; filename=#{filename}",
            'X-Accel-Redirect' => "/couch/#{config[:database]}/#{id}/#{filename}"
          },
          []
        ]
      end
      
    end
  end
end