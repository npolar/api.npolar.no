module Npolar
  module Rack
  
    # Api::Rack::ValidateId assures that ids are safe
    # 
    # @example
    #  Api::Rack::ValidateId
    #
    class ValidateId < Rack::Middleware
  
      CONFIG = {
        :code => 403,
        :message => "Invalid id",
        :except => lambda { |request| ["POST"].include? request.request_method },
        :id => nil
      }
      
      # @return Boolean
      def condition?(request)
        @explanation = []

        if id(request) =~ /^_/
          @explanation << "cannot start with _"   
        end

        #if id(request) =~ /[\/]/
        #  @explanation << "cannot contain /"   
        #end

        if id(request) =~ /(\s|%20)+/
          @explanation << "blanks are banned"   
        end

        @explanation.any?
      end

      # Unfortunately request is a vanilla Rack::Request, we have to guestimate the id
      def id(request)
        request.path_info.split("/").last
      end
  
    #for json id and _id should be identical and also identical to request.id

    end
  end
end
# FIXME: undefined method `handle' for #<Npolar::Rack::ValidateId:0x00000002020448>