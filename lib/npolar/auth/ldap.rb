require "net/ldap"
require "digest/sha1"
require "base64"

module Npolar
  module Auth

    # https://github.com/ruby-ldap/ruby-net-ldap
    class Ldap < Net::LDAP

      DEFAULT_DOMAIN = "npolar.no"

      # TODO: move this to config
      ROLES_CN = "cn=roles"
      API_DN = "cn=systems,dc=polarresearch,dc=org"
      USERS_DN = "cn=users,dc=polarresearch,dc=org"

      attr_accessor :log

      def self.ssha(password, salt)
        "{SSHA}"+Base64.encode64(Digest::SHA1.digest(password+salt)+salt).chomp!
      end
    
      def self.salt
        Base64.encode64(Digest::SHA1.digest("#{rand(64)}/#{Time.now.to_f}/#{Process.pid}"))[0..7]
      end

      def self.authenticator(domain=DEFAULT_DOMAIN)
        log.debug "Npolar::Auth::Ldap.authenticator"

        lambda { | ldap, request |
          ldap.domain = domain
          match?(request.username, request.password)
        } 
      end

      def self.config=(config)
        unless config.is_a? Hash
          if File.exists? config          
            config = JSON.parse(File.read(config), :symbolize_names => true)
            methods = ["simple", "simple_tls", "anonymous"]
            config[:auth][:method] = methods.include?(config[:auth][:method]) ?
              config[:auth][:method].to_sym
              : :simple
          end
        end
        @@config=config
      end

      def self.config
        @@config
      end
  
      def match? username, password
        # make sure it's in LDAP form: user@domain.no
        mail = massage_username(username)
        result = bind_as(:base => USERS_DN, :filter => "(mail=#{mail})", :password => password)

        if result and result[0].mail[0] == mail
            true
        else
            false
        end
      end

      def roles(system, username)
        discovered_roles = [] 

        # make sure it's in LDAP form: user@domain.no
        username = massage_username(username)

        # try to get uid of username
        uid = nil
        search(:base => USERS_DN, :filter=> Net::LDAP::Filter.eq("mail", username), :attributes => ["uid"]) do |entry|
          uid = entry[:uid][0]
        end

        if uid == nil
          log.debug "Could not find uid for username=#{username}"
        else
          log.debug "Discovered LDAP uid=#{uid} for username=#{username}"

          # see which roles for this system have a roleOccupant with this uid
          filter = Net::LDAP::Filter.eq("roleOccupant", "uid=#{uid}," + USERS_DN)
          dn = ROLES_CN + ",cn=#{system}," + API_DN
          search(:base => dn, :filter => filter, :return_result => false)  do |entry|
            discovered_roles << entry[:cn][0]
          end
        end

          log.debug("Discovered LDAP roles: #{discovered_roles} for username=#{username} in system=#{system}") 

        discovered_roles
      end

      def domain
        @domain ||= DEFAULT_DOMAIN
      end

      def domain=domain
        @domain = domain
      end

      # append @npolar.no stub if username doesn't have it
      def massage_username(username)
        if username !~ /[@]/
          username += "@" + domain
        end
        username
      end

      def log
        @log ||= Npolar::Api.log
      end

    end
  end
end
