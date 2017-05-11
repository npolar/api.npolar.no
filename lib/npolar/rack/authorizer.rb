module Npolar
  module Rack
    class Authorizer < Rack::Middleware

      EDITOR_ROLE = "editor"

      READER_ROLE = "reader"

      SYSADMIN_ROLE = "sysadmin"

      CONFIG = {
        :authorized? => lambda { | auth, system, request |
          if ["GET", "HEAD", "OPTIONS"].include? request.request_method
            auth.roles(system, request.username).include? READER_ROLE or auth.roles(system, request.username).include? EDITOR_ROLE or auth.roles(system, request.username).include? SYSADMIN_ROLE
          elsif ["POST", "PUT", "DELETE"].include? request.request_method
            auth.roles(system, request.username).include? EDITOR_ROLE or auth.roles(system, request.username).include? SYSADMIN_ROLE
          else
            false
          end
        },
        :authenticated? => lambda { | auth, request |
          auth.match?(request.username, request.password)
        },
        :auth => nil,
        :system => nil,
        :except? => nil,
      }

      def self.authorize(role=Npolar::Rack::Authorizer::SYSADMIN_ROLE)
        lambda {| auth, system, request | auth.roles(system, request.username).include? role }
      end

      def self.authorize_text(api)
        writes = ["POST", "PUT", "DELETE"]
        authorize_text = case api.open
          when true then "GET, HEAD, OPTIONS to * and "+writes.join(", ")
          else api.verbs.join(", ")
        end
        "#{api.path} authorize #{authorize_text} to \"#{api.auth.authorize}\" in system \"#{api.auth.system}\" using #{api.auth.authorizer or "Npolar::Auth::Couch"}"
      end

      def authenticated?
        begin
          if config[:authenticated?].is_a? Proc
            config[:authenticated?].call(auth, request)
          else
            false
          end
        rescue => e
          
          unless "test" == ENV["RACK_ENV"]
            puts __FILE__+":#{__LINE__} #{e.inspect}\n"+"="*80+"\n"+e.class.name+"\n"+e.message
            #puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
          end

          false

        end
      end

      def authorized?
        begin
          if config[:authorized?].is_a? Proc
            config[:authorized?].call(auth, system, request)
          else
            false
          end

        rescue => e

          unless "test" == ENV["RACK_ENV"]
            puts __FILE__+":#{__LINE__} #{e.inspect}\n"+ "="*80+"\n"+e.class.name+"\n"+e.message
            puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
          end

          false
          
        end
        
      end

      def call(env)
        @request = Npolar::Rack::Request.new(env)
        if "OPTIONS" == request.request_method or except?
          return app.call(env)
        end

        if auth.respond_to? :username=
          auth.username = request.username
        end

        unless authenticated?
          log.info "#{request.request_method} #{request.path} [#{self.class.name} using #{auth.class.name}]: 401"
          return http_error(401, "Failed authentication, invalid username or password")
        end

        if authorized?
          app.call(env)
        else
          log.info "#{request.request_method} #{request.path} [#{self.class.name} using #{auth.class.name}]: 403"
          error = { "error" => { "status" => 403, "reason" => "Forbidden", "explanation" => "Failed authorization" } }
          [403, {"Content-Type" => "application/json"}, [error.to_json]]
        end
      end

      def auth
        @auth ||= config[:auth]
      end

      def auth=auth
        @auth=auth
      end

      def except?
        return false unless config.respond_to? :key? and config.key? :except?
        case config[:except?]
          when true, false then config[:except?]
          when Proc then config[:except?].call(request)
          else false
        end
      end

      def system
        @system ||= config[:system]
      end

      def system=system
        @system=system
      end

    end
  end
end
