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
        log.info "Cleaning input!!! [#{self.class.to_s}]"
        t0 = Time.now
        data = Yajl::Parser.parse(request.body.read)

        cleaned = clean(data)
        request.env["rack.input"] = StringIO.new(cleaned.to_json)

        log.info "Input cleaned in #{Time.now - t0} [#{self.class.to_s}]"
        app.call(request.env)
      end

      def create?(request)
        ["PUT", "POST"].include?(request.request_method)
      end

      def clean(data)
        cleaned = clean_content(data)
        clean_content(cleaned)
      end

      def clean_content(data)
        if data.is_a? Array
          return clean_array(data)
        elsif data.is_a? Hash
          return clean_hash(data)
        end

        data
      end

      def clean_hash( data )
        # When not a Float or Boolean.
        # And the value is nil or empty.
        # Remove the key-value pair.
        data.reject!{|k,v| (!v.is_a?( Float ) && ![true,false].include?(v)) && (v.nil? || v.empty? )}

        # Loop through the remaining items and clean
        data.each do |k,v|
          data[k] = clean(v)
        end

        data
      end

      def clean_array( data )
        # When not a Float or Boolean.
        # And the element is nil or empty.
        # Remove the element.
        data.reject!{|e| (!e.is_a?( Float ) && ![true,false].include?(e)) && (e.nil? || e.empty?)}

        # Loop remaining elements and clean
        data.map!{|e| clean(e)}
      end

    end
  end
end
