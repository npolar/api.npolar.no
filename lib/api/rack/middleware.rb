require "rack/utils"

module Api
module Rack
  class Middleware
 
    attr_reader :app
    attr_reader :config
    
    # Default config hash  
    CONFIG = {
      :content_type => "application/json"
    }

    ##
    # @param  [#call]                       app
    # @param  [Hash{Symbol => Object}]      config

    def initialize(app, config = {})
      unless only_valid_keys?(config, self.class::CONFIG.keys)
        raise(ArgumentError, "Unknown config key(s): #{unknown_keys(config, self.class::CONFIG.keys).join(", ")}")
      end

      config = CONFIG.merge(self.class::CONFIG).merge config
      @app, @config = app, config
    end

    ##
    # @param  [Hash{String => String}] env
    # @return [Array(Integer, Hash, #each)]
    # @see    http://rack.rubyforge.org/doc/SPEC.html
    def call(env)
      request = ::Rack::Request.new(env)
      trigger?(request) ? handle(request) : app.call(env)
    end



    def error_body(request)
      error_body = error_hash(config[:code],"#{config[:message]}: #{explanation(request).join(", ")}")
      if config[:content_type] =~ /json/
        error_body = error_body.to_json
      else
        
      end
    end

    def explanation(request)
      []
    end

    # @config [Array{String}]               :params     ([])
    # @config []                            :methods    (METHODS)  
    # @config [String]                      :except    (Proc.new)
    def except?(request)
      if config[:except].is_a? Proc
        return true === config[:except].call(request)
      else
        false
      end
    end

    def handle(request)
      [ config[:code],
        {"Content-Type" => "#{config[:content_type]}; charset=utf-8"},
        [error_body(request)]
      ]
    end

    def only_valid_keys?(keys, *valid_keys)
      unknown_keys(keys, valid_keys).empty?
    end

    def unknown_keys(keys, *valid_keys)
      if keys.is_a? Hash
        keys = keys.keys
      end
      # From https://github.com/rails/rails/blob/39e1ac658efc80e4c54abef4f1c7679e4b3dc2ac/activesupport/lib/active_support/core_ext/hash/keys.rb#L45
      unknown_keys = keys - [valid_keys].flatten
      unknown_keys
    end


    def error_hash(status, explanation=nil)
      klass = case status.to_i
        when 100..199 then "Informational"
        when 200..299 then "Successful"
        when 300..399 then "Redirection"
        when 400..499 then "Client Error"
        when 500..599 then "Server Error"
        else "Unknown"
      end

      {"error"=>{"status"=>status, "reason"=>reason(status), "explanation" => explanation, "class" => klass}}

    end

    def error_body(request)
      ""
    end

    def reason(status)
      ::Rack::Utils::HTTP_STATUS_CODES[status]
    end

    ##
    # Returns true if required parameter is missing or blank
    # Returns false if no config[:params] is set or if it's empty
    # Returns false if the except block yields true
    # @param  [Rack::Request] request
    # @return [Boolean]
    def trigger?(request)
      if config[:except].is_a? Proc
        return false if except?(request)
      end
      condition?(request)
    end


  end
end
end