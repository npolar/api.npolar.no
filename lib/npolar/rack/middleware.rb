require "rack/utils"

module Npolar
  module Rack
    class Middleware
  
      extend Forwardable # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/forwardable/rdoc/Forwardable.html
  
      # Delegate HTTP request and response methods
      def_delegators :request, :id, :id=, :id?, :params, :params=, :path, :request_method
      def_delegators :response, :status, :headers, :body, :status=, :headers=, :body=, :<<, :each
   
      attr_accessor :app, :auth,:explanation, :config, :request, :response, :storage, :log
      
      # Default config hash  
      CONFIG = {
        :headers => { "Content-Type" => "application/json; charset=utf-8" }
      }
  
      ##
      # @param  [#call]                       app
      # @param  [Hash{Symbol => Object}]      config
      def initialize(app=nil, config = {})
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
        @request = Npolar::Rack::Request.new(env)
        trigger?(request) ? handle(request): app.call(env)
        
      end
  
      # 
      def condition? request
        false 
      end
  
      def error_body(request)
        error_body = error_hash(config[:code],"#{config[:message]}: #{explanation(request).join(", ")}")
      end
  
      def explanation(request)
        @explanation ||= []
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
          "params" => request.params,
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
      # Returns true if required parameter is missing or blank
      # Returns false if no config[:params] is set or if it's empty
      # Returns false if the except block yields true
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
      #RFC 5424 defines eight severity levels:
  
      #Code	Severity	Description	General Description
      #0	Emergency	System is unusable.	A "panic" condition usually affecting multiple apps/servers/sites. At this level it would usually notify all tech staff on call.
      #1	Alert	Action must be taken immediately.	Should be corrected immediately, therefore notify staff who can fix the problem. An example would be the loss of a backup ISP connection.
      #2	Critical	Critical conditions.	Should be corrected immediately, but indicates failure in a primary system, an example is a loss of primary ISP connection.
      #3	Error	Error conditions.	Non-urgent failures, these should be relayed to developers or admins; each item must be resolved within a given time.
      #4	Warning	Warning conditions.	Warning messages, not an error, but indication that an error will occur if action is not taken, e.g. file system 85% full - each item must be resolved within a given time.
      #5	Notice	Normal but significant condition.	Events that are unusual but not error conditions - might be summarized in an email to developers or admins to spot potential problems - no immediate action required.
      #6	Informational	Informational messages.	Normal operational messages - may be harvested for reporting, measuring throughput, etc. - no action required.
      #7	Debug	Debug-level messages.	Info useful to developers for debugging the application, not useful during operations.
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