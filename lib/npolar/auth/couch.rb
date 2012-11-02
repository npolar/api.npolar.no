
require 'digest/sha1'
require 'base64'

module Npolar
  module Auth
      class Couch

        extend Forwardable
        def_delegators :couch, :delete, :get, :head, :post, :put, :formats, :accepts

        attr_reader :couch, :username

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

          if user.key? "ssha_password" and user["ssha_password"] === base64_ssha(request_password) 
            true
          else
            false
          end
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
        def roles(system)

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

  def ssha(password, salt="salt")
    "{SSHA}"+Base64.encode64(Digest::SHA1.digest(password+salt)+salt).chomp!
  end

  def base64_ssha(ssha_string)
    unless ssha_string =~ /^{SSHA}/
      ssha_string = ssha(ssha_string)
    end
    Base64.encode64(ssha_string).chomp!
  end

  def salt
    Base64.encode64(Digest::SHA1.digest("#{rand(64)}/#{Time.now.to_f}/#{Process.pid}"))[0..7]
  end


    
    end
  end
end