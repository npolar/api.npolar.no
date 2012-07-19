module Npolar
  module Rack
  
    # Rack::RequireParam assures that one or more parameters are present on each request
    # Missing a required parameter causes a "400 Bad Request"
    # 
    # @example
    #  use Rack::RequireParam, :params => ["apikey"]
    #  use Rack::RequireParam, :params => ["apikey"], :except => lambda { |request| ["GET", "HEAD"].include? request.request_method }
    #
    class RequireParam < Middleware
  
      CONFIG = {
        :code => 412,
        :message => "Required parameter(s) missing or blank: ",
        :params => [],
        :except => nil
      }
      
      # @return Boolean
      def condition?(request)
        missing_params(request).any?  
      end

      def handle(request)
        http_error(CONFIG[:code], CONFIG[:message]+explanation(request).join(","))
      end
  
      # @return #each
      def explanation(request)
        missing_params(request)
      end
  
      ##
      # Returns missing parameters including blanks (like foo and bar in foo=&bar)
      # @param  [Rack::Request] request
      # @return [Array]
      def missing_params(request)
        missing = []
        required_params.each do | rp |
          if request.params.keys.include? rp
            if request.params[rp].nil? or request.params[rp].empty?
              missing << rp
            end
          else
            missing << rp
          end
        end
        missing
      end
  
      ##
      # @return Array
      #
      def required_params
        if config[:params].is_a? String
          config[:params] = [config[:params]]
        end
        config[:params] ||= []
      end
  
    end
  end
end