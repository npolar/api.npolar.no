require "net/ldap"
require "digest/sha1"
require "base64"

module Npolar
  module Auth

    # https://github.com/ruby-ldap/ruby-net-ldap
    class Ldap < Net::LDAP

      DEFAULT_DOMAIN = "npolar.no"

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

        mail = force_domain(username)
        result = bind_as(:base => "cn=users,#{base}", :filter => "(mail=#{mail})", :password => password)

        if result.any? and result[0].mail[0] == mail
          true
        else
          false
        end

      end

      def roles(system, username)
        if system.nil? or username.nil? or system == "" or username == ""
          raise ArgumentError, "Cannot find roles with blank username and/or system"
        end
        
        username = force_domain(username)

        uid = cn = dn = nil

        search(:filter=> Net::LDAP::Filter.eq("mail", username)) do |entry|
          dn = entry[:dn][0]
          cn = entry[:cn][0]
          uid = entry[:uid][0]
        end

        ldap_result = get_operation_result
        if ldap_result.code > 0
          message = "LDAP search failed with status #{ldap_result.code}: #{ldap_result.message}"
          log.fatal message
          raise message
        end

        if uid.nil?
          message =  "LDAP #{host} does not contain username=#{username}"
          log.fatal message
          raise message
        end
          
        roles = roles_for_dn(dn, system)
        log.debug("LDAP roles = #{roles} directly assigned #{cn} (#{username}) in system #{system}")

        gdn = groups_for_dn(dn, system)
        log.debug "#{cn} (#{username}) has groups: #{gdn}"
        
        gdn.each do |group_dn|  
          group_roles = roles_for_dn(group_dn, system)
          if group_roles.any?
            log.debug("#{group_roles} assigned #{cn} (#{username}) in system #{system} via group membership in #{gdn}")
            roles += group_roles
          end       
        end
   
        roles = roles.uniq
        log.info("LDAP roles = #{roles} for #{cn} (#{username}) in system #{system}")
        roles
      end

      def domain
        @domain ||= DEFAULT_DOMAIN
      end

      def domain=domain
        @domain = domain
      end

      def roles_for_dn(dn, system)
        roles = []
        filter_roles_for_dn = Net::LDAP::Filter.eq("roleOccupant", dn)
        search(:filter => filter_roles_for_dn, :base => "cn=#{system},cn=systems,#{base}") do |entry|
          roles << entry[:cn][0]
        end
        roles
      end

      def groups_for_dn(dn, system)
        gdn = []
        filter_groups_for_dn = Net::LDAP::Filter.eq("uniqueMember", dn)         
        search(:filter => filter_groups_for_dn, :base => "cn=groups,#{base}").each do |entry|
          gdn << entry[:dn][0]
        end
        gdn
      end

      def base
        @@config[:base]
      end

      def host
         @@config[:host]
      end

      # append @npolar.no stub if username doesn't have it
      def force_domain(username)
        if username !~ /[@]/
          username += "@" + domain
        end
        username
      end

      def log
        @log ||= Logger.new(STDERR)
      end

    end
  end
end
