#encoding: utf-8
require 'iconv'
require 'csv'
require 'pp'

module Npolar
  module Rack
   
    class ZeppelinTsvParser < Npolar::Rack::Middleware
      
      def condition?(request)
        create?(request)
      end
      
      def handle(request)
        log.info "@ZeppelinTsvParser: parsing input"
        t0 = Time.now
        data = request.body.read
       
        docs = parse(data) 
        request.env["rack.input"] = StringIO.new(docs.to_json)
        
        log.info "@TsvParser: Input parsed in #{Time.now - t0}"
        app.call(request.env)     
      end
      
      def create?(request)
        ["PUT", "POST"].include?(request.request_method)
      end
     
      # parse text data, returns array of docs
      def parse(data)

        # convert to utf-8
        ic = Iconv.new('UTF-8', 'WINDOWS-1252')
        data_utf8 = ic.iconv(data + ' ')[0..-2]

        # split into nice rows
        rows = data_utf8.split(/\r\n?|\n/)

        # to store units info
        units = {}

        # reformat header
        header = []
        rows[0].split(/\t/).each do |name|
          # extract unit information
          unit_match = name.match(/\[(.+)\]/)
          if unit_match
            unit_name = unit_match[1]
          end

          name = name.gsub(/\[.+\]/, "").strip
          name = name.gsub(/ /, "_")

          if unit_name
            units[name] = unit_name
          end

          header << name
        end
 
        # read values, store each doc in array
        docs = []

        rows.drop(1).each do |row|
          doc = {}
          row.split(/\t/).each_with_index do |value, index|
            name = header[index]
            if !value.nil? and !value.empty?
              # try to see if this can be a float
              begin
                value = Float(value.gsub(',', '.'))
              rescue ArgumentError
              end

              doc[name] = value
            end
          end

          docs << doc
        end

        docs
      end
      
    end
  end
end
