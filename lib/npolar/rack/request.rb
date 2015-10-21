module Npolar
  module Rack
    class Request < ::Rack::Request
    
      def body=string
        env["rack.input"] = StringIO.new(string)
      end

      # Extract format from request
      def format
   
        # If &format= is present we let that win
        if params.size > 0 and params.key?("format")
          format = params["format"]
        else
          # No &format, let Accept header win for GET, DELETE and

          if ["PUT", "POST"].include? request_method
            # Use Content-Type for POST, PUT
            format = media_format
          else
            # GET and DELETE, use Accept header
            format = accept_format
          end
        end
  
        if format.empty?
          # Still no format, go for .format
          format = format_from_path
        end
        
        # Still empty, set to ""
        if format.empty?
          format = ""
        end
        format
      end
  
      # Extract format from path info
      def format_from_path

        return "" if path_info.nil? or path_info !~ /[.]/
  
        format = path_info.split(".").last
        
        if format =~ /[\w+\/]/
          format = format.split("/")[0]
        end
  
        format
      end
  
      # Convenience
      def headers
        ::Rack::Utils::HeaderHash.new(env)
      end
  
  
      # Stupid, but we only care about the first accept header format
      def accept_format
        return "" if env['HTTP_ACCEPT'].nil?
  
        format = env['HTTP_ACCEPT'].scan(/[^;,\s]*\/[^;,\s]*/)[0].split("/")[1]
  
        if format =~ /[+]/
          format = format.split("+")[0]
        end
  
        format
      end
  
  
      # Returns incoming media format
      # POST: Use Content-Type header
      # PUT: Use regular format from path, Content-Type if format is blank
      def media_format
        media_format = ""
        if media_type =~ /[\/]/
          media_format = media_type.split("/")[1]
          if "x-www-form-urlencoded" == media_format
            media_format = format # use regular format instead, we never want form data
          end
        end
  
        media_format
      end
  
      # Extract multi params (repeated GET params) like fq=foo:bar&fq=bar:foo
      def multi(var)
        vars = self.env["QUERY_STRING"].split("&").select {|p| p =~ /^#{var}=(.*)/}
        multi = vars.map { |v|
          v = v.split("#{var}=")[1]
          v = v.nil? ? "" : v
        }
        # Special case for ?foo& or &foo&
        if self.env["QUERY_STRING"] =~ /(^[?]#{var}|[&]#{var})&/
          multi << nil
        end
        multi
      end
  
      # Extract id (remove trailing .format)
      def id
  
        id = path_info.split("/")[1]

        # Fix for /path/id.with.dot like /person/full.name - where format is "json" (derived from either Accept or Content-Type)
        if ["html", "json", "xml"].include? format
          if not id.nil? # for POST id is null
            id = id.gsub(/\.(html|json|xml)$/, "")
          end
          
        else
          
          # Otherwise, remove trailing .json or .xml
          if id =~ /[.]/
            id = id.split(".")
            id.pop
            id = id.join(".")
          end
          
        end
      
        if id == [] or id.nil?
          id == ""
        end
        
        id
  
      end

      def json?
        format == "json" or media_type =~ /^application\/json$/  
      end
  
      # Request has id?
      def id?    
        if id.nil? or id.empty? or id =~ /\s+/
          false
        else
          true
        end
      end
  
  
      #client_ip = request.env['HTTP_X_FORWARDED_FOR'].nil? ? request.remote_ip : request.env['HTTP_X_FORWARDED_FOR']
      # request.media_type == "application/x-www-form-urlencoded"
  
      def read?
        not write?
      end
  
      def write?
        ["DELETE", "PUT", "PATCH", "POST"].include? request_method
      end
      alias :edit? :write?
  
      # Search request?
      # A serarch is a GET request with GET parameter "q"
      def search?
        unless /GET|HEAD/ =~ request_method
          return false
        end
  
        if id? 
          false
        else
          true
        end
      end
  
      def username
        
        if headers["HTTP_AUTHORIZATION"] =~ /^Bearer\s[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/
         
          payload = headers["HTTP_AUTHORIZATION"].split("Bearer ")[1].split(".")[1]
          decoded = Base64.decode64(payload).strip

          if decoded =~ /^{/ and decoded =~ /"email"/ and decoded =~ /[:]/
            # OUCH the following crashes bad UTF-8
            # JSON.parse(decoded)["email"]
            decoded.split('"email"')[1].split(":")[1].split(",")[0].gsub(/["]/, "")
            
          else
            ""
          end
        else
          if false == basic.provided? or basic.username.empty?
            ""
          else
            URI.decode(basic.username).force_encoding('utf-8')
          end
        end
      end
  
      def password
        if false == basic.provided?
          ""
        else
          basic.credentials.last
        end
      end
  
      def basic
        ::Rack::Auth::Basic::Request.new(env)
      end

    end
  end
end
