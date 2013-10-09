#encoding: utf-8
require 'iconv'
require 'csv'
require 'pp'

module Npolar
  module Rack
   
    class ZeppelinTsvParser < Npolar::Rack::Middleware

      # fields, in the order they appear posted by Tor Ivan
      @@header = [
        "t2_last_sampling",
        "t1_first_sampling",
        "mean_dif_temp",
        "max_dif_temp",
        "min_dif_temp",
        "s_dif_temp",
        "mean_dir_temp",
        "max_dir_temp",
        "min_dir_temp",
        "s_dir_temp",
        "mean_glob_temp",
        "min_glob_temp",
        "s_glob_temp",
        "mean_ir_temp",
        "max_ir_temp",
        "min_ir_temp",
        "s_ir_temp",
        "mean_dif_solar",
        "max_dif_solar",
        "min_dif_solar",
        "s_dif_solar",
        "mean_dir_solar",
        "max_dir_solar",
        "min_dir_solar",
        "s_dir_solar",
        "mean_glob_solar",
        "max_glob_solar",
        "min_glob_solar",
        "s_glob_solar",
        "mean_ir_solar",
        "max_ir_solar",
        "min_ir_solar",
        "s_ir_solar",
        "mean_tacho_dif",
        "max_tacho_dif",
        "min_tacho_dif",
        "s_tacho_dif",
        "mean_tacho_glob",
        "max_tacho_glob",
        "min_tacho_glob",
        "s_tacho_glob"
      ]      

      def condition?(request)
        create?(request)
      end
      
      def handle(request)
        log.info "@ZeppelinTsvParser: parsing input"
        t0 = Time.now
        data = request.body.read
       
        docs = parse(data) 
        request.env["rack.input"] = StringIO.new(docs.to_json)
        request.env['CONTENT_TYPE'] = "application/json"
        
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
=begin
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
=end
 
        # read values, store each doc in array
        docs = []

        rows.each do |row|
          doc = {}
          row.split(/\s+/).each_with_index do |value, index|
            name = @@header[index]
            if !value.nil? and !value.empty?
              # try to see if this can be a float
              begin
                value = Float(value.gsub(',', '.'))
              rescue ArgumentError
              end

              doc[name] = value
            end
          end

          # point to our schema
          doc["schema"] = "http://api.npolar.no/schema/radiation-zeppelin-1.0-rc1"

          docs << doc
        end

        docs
      end
      
    end
  end
end
