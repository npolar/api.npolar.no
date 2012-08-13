module Npolar
  module Rack
    class Request < ::Rack::Request
      
    # Extract format from request
    def format
      format = format_from_path

      if format.empty?
        format = params["format"] ||= ""
      end

      if format.empty?
        format = accept_format
      end

      if format.empty? 
        format = media_format
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


    # Extract id
    def id

      id = path_info.split("/")[1]

      if id =~ /[.]/
        id = id.split(".")[0]
      end
    
      if id == [] or id.nil?
        id == ""
      end

      id


    end

    # Request has id?
    def id?    
      if id.nil? or id.empty? or id =~ /\s+/
        false
      else
        true
      end
    end

    def read?
      not write?
    end

    def write?
      ["DELETE", "PUT", "PATCH", "POST"].include? request_method
    end
    #alias :edit? :write?

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
      if false == basic.provided? or basic.username.empty?
        ""
      else
        basic.username
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