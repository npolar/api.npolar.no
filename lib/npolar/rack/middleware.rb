require "rack/utils"
require "logger"
require "yajl/json_gem"

module Npolar
  module Rack
    class Middleware
  
      extend Forwardable # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/forwardable/rdoc/Forwardable.html
  
      # Delegate HTTP request and response methods
      def_delegators :request, :id, :id=, :id?, :params, :params=, :path, :request_method
      def_delegators :response, :status, :headers, :body, :status=, :headers=, :body=, :<<, :each
   
      attr_accessor :app, :auth, :explanation, :config, :request, :response, :storage, :log
      
      # Default config hash  
      CONFIG = {
        :headers => { "Content-Type" => "application/json; charset=utf-8" },
        :app => lambda {|env| [404, { "Content-Type" => "application/json; charset=utf-8" }, ["404 Not Found"]]}# @todo FIXME JSONize Npolar::Rack::NotFound
      }
  
      ##
      # @param  [#call]                       app
      # @param  [Hash{Symbol => Object}]      config
      def initialize(app=nil, config = {})
        #config = Hashie::Mash.new(config)
        unless only_valid_keys?(config, self.class::CONFIG.keys)
          raise(ArgumentError, "Unknown config key(s): #{unknown_keys(config, self.class::CONFIG.keys).join(", ")}")
        end
            
        config = CONFIG.merge(self.class::CONFIG).merge config
        if app.nil?
          app = config[:app]
        end
        
        @app, @config = app, config
        @log = ::Logger.new(STDERR)
      end
  
      ##
      # @param  [Hash{String => String}] env
      # @return [Array(Integer, Hash, #each)]
      # @see    http://rack.rubyforge.org/doc/SPEC.html
      def call(env)
        @request = Npolar::Rack::Request.new(env)
        trigger?(request) ? handle(request): app.call(env)  
      end

      ##
      # @param  [Request] request
      # @return [true|false]
      def condition? request
        false 
      end
  
      def error_body(request)
        error_body = error_hash(config[:code],"#{config[:message]}: #{explanation(request).join(", ")}")
      end
  
      def explanation(request)
        @explanation ||= []
      end

      def headers(format, encoding="utf-8")
        content_type = case format
          when "json", "xml" then "application/#{format}"
          when /^geo\+?json$/ then "application/vnd.geo+json"
          when "atom" then "application/atom+xml"
          when "html" then "text/html"
          when "csv", "text" then "text/plain"
          when "js", "javascript", "jsonp" then "application/javascript"
          else raise ArgumentError("Unknown format: #{format}")
        end
        {"Content-Type" => "#{content_type}; charset=#{encoding.downcase}"}
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
  
      def only_valid_keys?(keys, *valid_keys)
        unknown_keys(keys, valid_keys).empty?
      end
  
      def unknown_keys(keys, *valid_keys)
        if keys.is_a? Hash
          keys = keys.keys
        end

        unknown_keys = []

        unless keys.nil?
        # From https://github.com/rails/rails/blob/39e1ac658efc80e4c54abef4f1c7679e4b3dc2ac/activesupport/lib/active_support/core_ext/hash/keys.rb#L45
          unknown_keys = keys - [valid_keys].flatten
        end
        unknown_keys
      end

      def request_hash
        {
          "method" => request.request_method,
          "uri" => request.url,
          "id" => request.id,   
          "agent" => request.user_agent,
          "path" => request.script_name,
          "format" => request.format,
          "username" => request.username,
          "time" => ::DateTime.now.xmlschema,
          "ip" => request.ip
        }
      end
  
      def error_hash(status, explanation=nil)
        {"error"=>{
          "status"=>status,
          "reason"=>reason(status),
          "explanation" => explanation,
          "uri" => request.url,
          "id" => request.id,
          "host"=> `hostname`.chomp,
          "method" => request.request_method,
          "level" => level(status),
          "agent" => request.user_agent,
          "path" => request.script_name,
          "format" => request.format,
          "username" => request.username,
          "time" => ::DateTime.now.xmlschema,
          "ip" => request.ip,
          }
        }
  
      end
  
      def reason(status)
        ::Rack::Utils::HTTP_STATUS_CODES[status]
      end
  
      ##
      # Returns true if condition is true OR except? is true
      # Returns false condition is false
      # @param  [Rack::Request] request
      # @return [Boolean]
      def trigger?(request)
        except?(request) ? false : condition?(request)
      end
  
      def http_error(status, explanation=nil)
        
        error = error_hash(status, explanation).to_json+"\n"
        unless request.nil?
          if "HEAD" == request.request_method or 204 == status
            error = []
          end
        end
        Npolar::Rack::Response.new(error, status, config[:headers])
      end
  
      protected

      # http://en.wikipedia.org/wiki/Syslog#Severity_levels
      def level(status)
        case status
          when 100..199 then 6
          when 200..299 then 5
          when 300..399 then 4
          when 400..499 then 3
          when 500..599 then 2
        end
      end

    end
  end
end