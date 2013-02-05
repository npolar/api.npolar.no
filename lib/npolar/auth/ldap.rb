require "net/ldap"
require "digest/sha1"
require "base64"

module Npolar
  module Auth
    class Ldap < Net::LDAP

      DEFAULT_DOMAIN = "npolar.no"

      # TODO: move this to config.ru?
      ROLES_DN = "cn=roles,cn=api,cn=systems,dc=polarresearch,dc=org"
      USERS_DN = "cn=users,dc=polarresearch,dc=org"

      def self.ssha(password, salt)
        "{SSHA}"+Base64.encode64(Digest::SHA1.digest(password+salt)+salt).chomp!
      end
    
      def self.salt
        Base64.encode64(Digest::SHA1.digest("#{rand(64)}/#{Time.now.to_f}/#{Process.pid}"))[0..7]
      end


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

      def roles(username)
        discovered_roles = [] 

        # try to get uid of username
        uid = nil
        search(:base => USERS_DN, :filter=> Net::LDAP::Filter.eq("mail", username), :attributes => ["uid"]) do |entry|
          uid = entry[:uid][0]
        end

        if uid == nil
          Npolar::Api.log.debug "Could not find uid for username=#{username}"
        else
          Npolar::Api.log.debug "Discovered LDAP uid=#{uid} for username=#{username}"

          # see which roles have a roleOccupant with this uid
          filter = Net::LDAP::Filter.eq("roleOccupant", "uid=#{uid}," + USERS_DN)
          search(:base => ROLES_DN, :filter => filter, :return_result => false)  do |entry|
            discovered_roles << entry[:cn][0]
          end
        end
      
        Npolar::Api.log.debug("Discovered roles: #{discovered_roles} for username=#{username}") 

        discovered_roles
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
