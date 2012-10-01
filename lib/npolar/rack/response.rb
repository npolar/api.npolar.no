module Npolar
  module Rack
    class Response < ::Rack::Response


      ## Force Content-Type
      #unless response_headers["Content-Type"].nil?
      #  response["Content-Type"] = response_headers["Content-Type"]
      #end
      #
      ## Force UTF-8
      #if response["Content-Type"] !~ /; charset=/
      #  response["Content-Type"] +=  "; charset=utf-8"
      #end
      #
      ## Recalculate Content-Length (except on HEAD)
      #unless request.request_method =~ /HEAD/         
      #  # We don't recalculate content length on HEAD, that would always give 0 (and it should report length of a GET). 
      #  response["Content-Length"] = response_body.respond_to?(:bytesize) ? response_body.bytesize.to_s : response_body.size.to_s
      #end
      #
      ## Write body
      #unless request.request_method =~ /HEAD/    
      #  response_body = response_body.to_json if response_body.is_a? Hash
      #  
      #  # GET obviuously has body
      #  # POST/PUT returns the created resource 
      #  # DELETE has body if it failed
      #  response.write(response_body) 
      #else

      def finish(&block)
        if body.respond_to? :to_json
          body = body.to_json
        end
        super
      end

      

      def to_s
        s = ""
        body.each {|chunk| s += chunk }
        s
      end

    end
  end
end