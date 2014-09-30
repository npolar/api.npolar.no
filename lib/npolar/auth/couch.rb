require "openssl"
require "digest"
require "base64"

module Npolar
  module Auth
    class Couch

      extend Forwardable
      def_delegators :couch, :delete, :get, :head, :post, :put, :formats, :accepts

      attr_reader :couch, :username
      
      # PBKDF2-hash http://en.wikipedia.org/wiki/PBKDF2
      # From http://ruby-doc.org/stdlib-2.0/libdoc/openssl/rdoc/OpenSSL/PKCS5.html
      def self.pbkdf2(password)
        salt = "salt" #OpenSSL::Random.random_bytes(16)
        iterations = 20000
        digest = OpenSSL::Digest::SHA256.new
        Base64.encode64(OpenSSL::PKCS5.pbkdf2_hmac(password, salt, iterations, digest.digest_length, digest)).strip
      end
      
      # Equal time compare
      # From http://ruby-doc.org/stdlib-2.0/libdoc/openssl/rdoc/OpenSSL/PKCS5.html
      def self.equal?(a, b)
        unless a.length == b.length
          return false
        end
        cmp = b.bytes.to_a
        result = 0
        a.bytes.each_with_index {|c,i|
          result |= c ^ cmp[i]
        }
        result == 0
      end
      
      def self.sysadmin_user(id, password, email="", name="", groups=["api-sysadmin"], roles={})
        sysadmin_user = {
          id: id,
          email: email,
          name: name,
          type: "person",
          groups: groups,
          roles: roles,
          password: pbkdf2(password)
        }
      end
      
      def self.sysadmin_group
        { id: "api-sysadmin", type: "group", systems: ["api"],
            roles: { api: ["sysadmin"] }
        }
      end

      def initialize(couch)
        self.couch=couch
      end

      def couch=(couch)
        case couch
          when Storage::Couch then @couch = couch
          else @couch = Storage::Couch.new(couch)
        end
      end

      def match? request_username, request_password
        username=request_username
        user = get_user
        
        if not user.key? "password"
          return false
        end
        hashed_request_password = self.class.pbkdf2(request_password)
        puts hashed_request_password
        self.class.equal?(hashed_request_password, user["password"])
      end

      def username=username
        @username=username
      end

      def get_user
        if username.nil? or username.empty?
          raise Auth::Exception, "Blank username"
        end
        response = get(username)
        if 200 == response[0]
          JSON.parse(response[2])          
        else
          {}
        end
      end

      def group_roles
        gr = []
        groups.each do | group |
          group_roles = roles_for(group)
          gr << group_roles if group_roles.any?
        end
        gr
      end

      def groups
        get_object(username, "groups")
      end

      def roles_for(username)
        get_object(username, "roles")
      end

      def role?(system, role)
        roles = roles(system)
        if 1 == roles.size and roles[0].is_a? Hash and roles[0].key? system
          roles[0][system].include? role
        else
          false
        end
      end

      # roles = user roles + all group_roles
      def roles(system, username)

        roles = []
        user = self.get_user

        if user.key? "groups" and user["groups"].any?
          roles << group_roles
        end

        if user.key? "roles" and user["roles"].any?
          roles << roles_for(username)
        end

        # Convert from [{"api":["sysadmin"]},{"api":["reader"]}]
        roles = roles.flatten.select {|r| r.key? system} 
        roles = roles.map {|system_role| system_role[system]}.flatten.uniq
        # to ["sysadmin", "reader"]

        roles
      end

      def get_object(username, key)
       
        response = get(username)
        if 200 == response[0]
          o = JSON.parse(response[2])          
          if o.key? key
            o[key]
          else
            {}
          end
        else
          {}
        end
      end

      def get_array(username, key)
        o = get_object(username, key)
        if o.key? key
          o[key]
        else
          []
        end
      end
          
    end
  end
end
