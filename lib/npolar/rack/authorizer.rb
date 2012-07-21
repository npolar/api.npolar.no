module Npolar
  module Rack
    class Authorizer < Rack::Middleware

      EDITOR_ROLE = "editor"

      READER_ROLE = "reader"

      SYSADMIN_ROLE = "sysadmin"

      CONFIG = {
        :authorized? => lambda { | auth, system, request |
          if ["GET", "HEAD"].include? request.request_method
            auth.roles(system).include? READER_ROLE or auth.roles(system).include? EDITOR_ROLE or auth.roles(system).include? SYSADMIN_ROLE
          elsif ["POST", "PUT", "DELETE"]
            auth.roles(system).include? EDITOR_ROLE or auth.roles(system).include? SYSADMIN_ROLE
          else
            false
          end

        },
        :authenticated? => lambda { | auth, request |
          
          if auth.match?(request.username, request.password)
            true
          else
            false
          end
        },
        :auth => nil,
        :system => nil,
        :except? => nil,
      }

      def authenticated?
        begin
          if config[:authenticated?].is_a? Proc
            config[:authenticated?].call(auth, request)
          else
            false
          end
        rescue => e
          puts __FILE__+":#{__LINE__} #{e.inspect}"
          puts "="*80+"\n"+e.class.name+"\n"+e.message
          puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
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
          puts __FILE__+":#{__LINE__} #{e.inspect}"
          puts "="*80+"\n"+e.class.name+"\n"+e.message
          puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
          false
        end
        
      end

      def call(env)
        @request = Npolar::Rack::Request.new(env)

        if except?
          return app.call(env)
        end

        if auth.respond_to? :username=
          auth.username = request.username
        end

        unless authenticated?
          return http_error(401, "Failed authentication, invalid username or password")
        end

        if authorized?
          app.call(env)
        else
          [403, {"Content-Type" => "text/html"}, ["Failed authorization"]]
        end
      end

      def auth
        config[:auth]
      end

      def auth=auth
        config[:auth]=auth
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
        config[:system]
      end

      def system=system
        config[:system]=system
      end

    end
  end
end