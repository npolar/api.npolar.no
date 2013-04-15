#encoding: utf-8
require 'iconv'
require 'csv'
require 'pp'

module Npolar
  module Rack
    
    class TsvParser < Npolar::Rack::Middleware
      
      def condition?(request)
        create?(request)
      end
      
      def handle(request)
        log.info "@TsvParser: parsing input"
        t0 = Time.now
        data = request.body.read
       
        doc = parse(data) 
        request.env["rack.input"] = StringIO.new(doc.to_json)
        
        log.info "@TsvParser: Input parsed in #{Time.now - t0}"
        app.call(request.env)     
      end
      
      def create?(request)
        ["PUT", "POST"].include?(request.request_method)
      end
     
      # parse text data 
      def parse(data)
        doc = {}

        # convert to utf-8
        ic = Iconv.new('UTF-8', 'WINDOWS-1252')
        data = ic.iconv(data + ' ')[0..-2]

        data = data.gsub(/\r\n?/, "\n")
        rows = data.split(/\n/)

        # reformat header
        header = []
        rows[0].split(/\t/).each do |name|
          name = name.gsub(/ /, "_")
          header << name
          doc[name] = []
        end
 
        # read values, store as arrays
        rows.drop(1).each do |row|
          row.split(/\t/).each_with_index do |value, index|
            name = header[index]
            if !value.nil? and !value.empty?
              doc[name] << value
            end
          end
        end

        # if some keys map to 1-element arrays,
        # transform those values into single values
        doc.each do |k, v|
          if v.length == 0
            doc[k] = nil
          elsif v.length == 1
            doc[k] = v[0]
          end
        end

        doc
      end
      
    end
  end
end