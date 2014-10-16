require "net/ldap"
require "digest/sha1"
require "base64"

module Npolar
  module Auth

    # https://github.com/ruby-ldap/ruby-net-ldap
    class Ldap < Net::LDAP

      DEFAULT_DOMAIN = "npolar.no"

      attr_accessor :log
      
      @@config = {}

      # Generate password hash using salted SHA1 (SSHA)
      def self.ssha(password, salt)
        "{SSHA}"+Base64.encode64(Digest::SHA1.digest(password+salt)+salt).chomp!
      end
    
      def self.salt
        Base64.encode64(Digest::SHA1.digest("#{rand(64)}/#{Time.now.to_f}/#{Process.pid}"))[0..7]
      end
        
      def self.extract_salt(hash)
        Base64.decode64(hash)[-4, 4]
      end
      
      def self.base64_ssha(password,salt)
        Base64.encode64(ssha(password, salt)).strip
      end

      def self.authenticator(domain=DEFAULT_DOMAIN)
        log.debug "Npolar::Auth::Ldap.authenticator"

        lambda { | ldap, request |
          ldap.domain = domain
          match?(request.username, request.password)
        } 
      end

      def self.config=(config)
        if config.to_s =~ /^ldap/
          p = URI::Parser.new
          ldap_uri = p.parse(config)
          ldap_uri.port = ldap_uri.scheme == "ldap" ? 389 : 636
          config = { host: ldap_uri.host, port: ldap_uri.port, base: ldap_uri.dn,
            auth: { username: ldap_uri.user, password: ldap_uri.password, method: :simple } 
          }
        elsif File.exists? config          
          config = JSON.parse(File.read(config), :symbolize_names => true)
          methods = ["simple", "simple_tls", "anonymous"]
          config[:auth][:method] = methods.include?(config[:auth][:method]) ? config[:auth][:method].to_sym : :simple
        end
        @@config=config
      end

      def self.config
        @@config
      end
  
      def match? username, password
        mail = force_domain(username)

        result = bind_as(:base => base, :filter => Net::LDAP::Filter.eq("mail", mail), :password => password)

        check_ldap_operation
        
        if false == result
          return false
        end
    
        if result[0].mail[0] == mail
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

        user = find_user_by_mail(username)

        dn = user[:dn]
        cn = user[:cn]
        uid = user[:uid]

        check_ldap_operation

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

      # @return Array of roles (as list of common names)
      def roles_for_dn(dn, system)
        roles = []
        filter_roles_for_dn = Net::LDAP::Filter.eq("roleOccupant", dn)
        search(:filter => filter_roles_for_dn, :base => "cn=#{system},cn=systems,#{base}") do |entry|
          roles << entry[:cn][0]
        end
        roles
      end

      # @return Array of groups (as list of DNs)
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
        username = CGI.unescape(username)
        if username !~ /[@]/
          username += "@" + domain
        end
        username
      end

      def log
        @log ||= Logger.new(STDERR)
      end

      # Search LDAP for username (mail)
      # @return user Hash
      def find_user_by_mail(mail)
        user = {}
        i = 0
        search(:filter=> Net::LDAP::Filter.eq("mail", mail)) do |entry|
          # entry -> Net::LDAP::Entry
          i += 1
          if i > 1
            raise "Found #{i} users with email #{mail}"
          end
          
          entry.each do |k,v|
            if v.size == 1
              user[k] = v[0]
            else
              user[k] = v
            end
          end
        end
        #log.debug user
        user
      end

      protected
  
      def check_ldap_operation
        ldap_result = get_operation_result
        # http://www.openldap.org/doc/admin24/appendix-ldap-result-codes.html
        if not [0,5,6,10,14].include? ldap_result.code
          message = "LDAP operation against #{host} failed with status #{ldap_result.code}: #{ldap_result.message}"
          log.fatal message
          raise message
        end
      end

    end
  end
end
