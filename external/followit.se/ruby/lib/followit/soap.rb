require "typhoeus"
require "nokogiri"

module Followit
  
  module Soap
    
    NAMESPACE = "http://tempuri.org/"
    
    attr_writer :uri, :log
     
    def execute(request,&block)
            
      #request.on_complete do |response|
      #  if response.success?
      #    # noop
      #  elsif response.timed_out?
      #    log.error("got a time out")
      #  elsif response.code == 0
      #    log.error(response.return_message)
      #  else
      #    log.error("HTTP request failed: " + response.code.to_s)
      #  end
      #end
      #log.debug request.url
      response = request.run
      
      log.debug "#{response.code} <- #{request.url} #{request}"
      
      faults = Nokogiri::XML(response.body).xpath("//soap:Fault")
      if faults.any?
        raise faults.to_xml
      end
      
      if block_given?
        response
      else
        response  
      end
      
    end
    
    def extract(response, xpath)
      @doc = Nokogiri::XML(response.body)
      @doc.xpath(xpath, { followit: NAMESPACE }.merge(@doc.document.namespaces))
    end
        
    def envelope(&block)
      Nokogiri::XML::Builder.new do |xml|
        xml.Envelope("xmlns:soap" => "http://www.w3.org/2003/05/soap-envelope",
          "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
          "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema") do
            xml.parent.namespace = xml.parent.namespace_definitions.first
          xml["soap"].Body(&block)
        end
      end
    end
    
    def request(envelope)
      Typhoeus::Request.new(uri,
        method: :post,
        body: envelope.to_xml,
        verbose: false,
        cookiefile: "/tmp/followit.se-login",
        cookiejar: "/tmp/followit.se-login",
        headers: {"Content-Type" => "text/xml", "Accept" => "application/soap+xml"}
      )
    end
    
    def uri
      @uri ||= self.class::URI
    end
    
    def log
      @log ||= Logger.new("/dev/null")
    end
    
    def xpath(xpath)
      @doc.xpath(xpath, { followit: NAMESPACE }.merge(@doc.document.namespaces))
    end
   
  end
end