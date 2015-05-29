module Followit
  class AuthService
    
    include Soap
    
    URI =  "http://total.followit.se/DataAccess/AuthenticationService.asmx"
    
    def initialize(username, password)
      @username = username
      @password = password
    end
    
    def username
      @username
    end
          
    def login
      execute(request(login_envelope(@username,@password)))
    end
      
    protected
    
    def login_envelope(username, password)
      envelope do |xml|
        xml.Login(xmlns: NAMESPACE) do
          xml.login username
          xml.password password
        end
      end
    end  
    
  end
end