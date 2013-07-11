module Npolar
  module Auth
    class Factory
      def self.instance(name, config)
        if name =~ /Couch$/
          Couch.new(config)
        elsif name =~ /Ldap/

        else
          raise "Unknown auth product: #{name}"
        end
        

      end

    end
  end
end
