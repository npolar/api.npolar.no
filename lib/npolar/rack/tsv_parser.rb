#encoding: utf-8
require 'iconv'
require 'csv'
require 'pp'

module Npolar
  module Rack
   
    # TODO: rename something specific to Zeppelin 
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
        ic = Iconv.new('UTF-8', 'WINDOWS-1252') # TODO: make 'encoding' a query parameter
        data_utf8 = ic.iconv(data + ' ')[0..-2]

        data_clean = data_utf8.gsub(/\r\n?/, "\n")
        rows = data_clean.split(/\n/)

        # to store units info
        doc['units'] = {}

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
            doc['units'][name] = unit_name
          end

          header << name
          doc[name] = []
        end
 
        # read values, store as arrays
        rows.drop(1).each do |row|
          row.split(/\t/).each_with_index do |value, index|
            name = header[index]
            if !value.nil? and !value.empty?
              # try to see if this can be a float
              begin
                value = Float(value.gsub(',', '.'))
              rescue ArgumentError
              end

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
       
        # create a filename for original document 
        source_fname = doc.fetch('Filename', 'source')
        tsv_fname = File.basename(source_fname, File.extname(source_fname)) + '.tsv'

        # store a copy of the file as an attachment
        doc["_attachments"] = {
          "#{tsv_fname}" => { 
            "content_type" => "text/tab-separated-values",
            "data" => Base64.encode64(data_utf8)
          }
        }

        doc
      end
      
    end
  end
end
