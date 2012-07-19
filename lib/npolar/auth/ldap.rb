require "net/ldap"

module Npolar
  module Auth
    class Ldap < Net::LDAP

      DEFAULT_DOMAIN = "npolar.no"

      def self.authenticator(domain=DEFAULT_DOMAIN)
        lambda { | ldap, request |
  
          ldap.domain = domain
          match?(request.username, request.password)
        } 
  
      end
  
      def match? username, password

        mail = username
        if mail !~ /[@]/
          mail += "@" + domain
        end

        result = bind_as(:filter => "(mail=#{mail})", :password => password)
        if result and result[0].mail[0] == mail
            true
          else
            false
          end
      end

      def domain
        @domain ||= DEFAULT_DOMAIN
      end

      def domain=domain
        @domain = domain
      end


    end
  end
end