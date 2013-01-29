module Npolar
  module Rack
    
    # [Functionality]
    #   * Clean empty values from json documents.
    #
    # [License]
    #   This code is licensed under the {http://www.gnu.org/licenses/gpl.html GNU General Public License Version 3} (GPLv3)
    #
    # @author Ruben Dens
    
    class JsonCleaner < Npolar::Rack::Middleware
      
      def condition?(request)
        create?(request)
      end
      
      def handle(request)
        log.info "@JsonCleaner: Cleaning input!!!"
        t0 = Time.now
        data = Yajl::Parser.parse(request.body.read)
        
        cleaned = clean(data)
        request.env["rack.input"] = StringIO.new(cleaned.to_json)
        
        log.info "@JsonCleaner: Input cleaned in #{Time.now - t0}"
        app.call(request.env)     
      end
      
      def create?(request)
        ["PUT", "POST"].include?(request.request_method)
      end
      
      def clean(data)
        if data.is_a? Array
          return clean_array(data)
        elsif data.is_a? Hash
          return clean_hash(data)
        end
        
        data
      end
      
      def clean_hash( data )
        data.reject!{|k,v| !v.is_a?( Float ) && (v.nil? || v.empty? )}
        
        data.each do |k,v|
          data[k] = clean(v)
        end
        
        data
      end
      
      def clean_array( data )
        data.reject!{|e| !e.is_a?( Float ) && (e.nil? || e.empty?)}
        
        data.map!{|e| clean(e)}
      end
      
    end
  end
end
