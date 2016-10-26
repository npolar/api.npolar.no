require "logger"
require "json"

module Telonics

#Telonics Data Report
#Report Format,Condensed,1
#Headers Row,24
#Data Source,Iridium
#TDC Version,2.26 SECO1481
#Conversion Parameters,TPF File,C:\Users\are\Documents\3_Datasenter\Tracking\Telonics\TPF\111123002A.tpf,Last Modified,2013.04.05 07:37:40,Programmed,2013.02.04 09:49:10
#
#CTN,659121A
#Comment,
#Iridium IMEI,300234011124710
#
#Report Period Begins,2013.04.11 18:00:00
#Report Period Ends,2014.03.12 20:03:58
#
#Report File Number,1 of 1
#File Coverage Begins,2013.04.11 18:00:00
#File Coverage Ends,2014.03.12 20:03:58
#
#Measurement Units,,,degrees,degrees,,,degrees,degrees,,meters,meters,meters,meters,,,,,degrees C,Hit,,,Yes/No,Yes/No,Yes/No,
#Resolution,,,,,,,0.000043,0.000043,,5,5,,5.00,,,,,,,,,,,,
#Range Minimum,,,,,2012.01.01 00:00:00,,-90.000000,-180.000000,,,,,0.00,,,,0,-40,,,,,,,
#Range Maximum,,,,,2046.01.01 00:00:00,,90.000000,180.000000,,,,,79.99,,,,65535,70,,,,,,,
#,,,,,,,,,,,,,,,,,,,,,,,,,
#Acquisition Time,Acquisition Start Time,Iridium CEP Radius,Iridium Latitude,Iridium Longitude,GPS Fix Time,GPS Fix Attempt,GPS Latitude,GPS Longitude,GPS UTM Zone,GPS UTM Northing,GPS UTM Easting,GPS Altitude,GPS Horizontal Error,GPS Horizontal Dilution,GPS Satellite Bitmap,GPS Satellite Count,Activity Count,Temperature,Satellite Uplink,Receive Time,Repetition Count,Low Voltage,Mortality,Predeployment Data,Error
#------------------

  class TelonicsCondensedCsvParser

    MESSAGE_REGEXP = /^,?\d{4}.\d{2}.\d{2}.\d{2}:\d{2}:\d{2}/
    HEADER = "Acquisition Time,Acquisition Start Time,Iridium CEP Radius,Iridium Latitude,Iridium Longitude,GPS Fix Time,GPS Fix Attempt,GPS Latitude,GPS Longitude,GPS UTM Zone,GPS UTM Northing,GPS UTM Easting,GPS Altitude,GPS Horizontal Error,GPS Horizontal Dilution,GPS Satellite Bitmap,GPS Satellite Count,Activity Count,Temperature,Satellite Uplink,Receive Time,Repetition Count,Low Voltage,Mortality,Predeployment Data,Error"
    REJECT_KEYS = [:gps_utm_easting, :gps_utm_northing, :gps_utm_zone]
    PREAMBLE_KEY_MAP = { ctn: :platform, iridium_imei: :imei}

    attr_writer :log

    def initialize(input=nil)
      if input.respond_to? :read
        @input = input
      else
        raise ArgumentError "Input is not IO object"
      end
    end

    def parse_preamble(input, map=PREAMBLE_KEY_MAP)

      @headers_row = nil
      h = { preamble: {}}

      input.each_with_index do |line, i|


        if (line.strip != "" && line !~ MESSAGE_REGEXP and line =~ /^[a-z\s]+,/i)


          if not @headers_row.nil? and @headers_row == i+1
              keys = line.split(",")
              self.keys = keys
              h[:preamble][:headers] = self.keys

          else

            k,v = line.split(",")
            k = k.downcase.gsub(/\s/, "_").to_sym

            if line =~ /Headers\sRow/i
              @headers_row = v.to_i
            end

            if map.key? k
              h[map[k]] = v.chomp
            elsif not v.nil?
              h[:preamble][k]=v.chomp
            else
              h[:preamble][k]=v
            end

          end

        end
      end


      h
    end

    def parse(input=nil)

      input = input.nil? ? @input : input

      if not input.respond_to? :read
        raise "No input IO provided"
      end
      @header = parse_preamble(input)
      #log.debug "Header: #{@header.to_json}"
      #log.debug "Keys (#{keys.size}): #{keys.to_json}"

      input.rewind
      rows = input.select {|line|
        line =~ MESSAGE_REGEXP
      }.map {|line|
        line.split(",").map {|col| col.chomp }
      }

      log.info "#{rows.size} messages in #{input.path}"
      if rows.any? {|m| m.size != keys.size }
        wrong = rows.select {|m| m.size != keys.size }.map {|r| r.size }
        raise "Wrong number of columns (not #{keys.size}) for at least #{wrong.size} row(s): #{wrong.uniq.to_json}"
      end

      rows.map {|row|
        message(row)
      }
    end

    def GeoJSON(opts={ })

      features = parse

      features = features.select {|m|
        not (m[:acquisition_time].nil? or m[:latitude].nil? or m[:longitude].nil?)
      }.map {|m|

        #log.info m.keys.to_json
        t = Time.parse(m[:acquisition_time])

        properties = {
          time: m[:acquisition_time],
          #satellites: m[:gps_satellite_count].to_i,
          technology: m[:technology],
          platform: m[:platform],
          imei: m[:imei].to_i,
          died: m[:mortality]
        }
        longitude = m[:longitude]
        latitude = m[:latitude]
        geometry = {
          type: "Point",
          coordinates: [longitude,latitude]
        }
        feature = { type: "Feature",
          geometry: geometry,
          # begin data duplication
          latitude: latitude,
          longitude: longitude,
          year: t.year,
          month: t.month,
          # end data duplication
          properties: properties
        }
        if m[:technology] == "iridium"
            feature[:properties][:cep] = m[:iridium_cep_radius]
        end
        #log.info feature
        feature
      }
      log.info "#{features.size} GPS points (GeoJSON Point features)"
      if opts.key? :time
        features = features.select {|f|
          Time.parse(f[:properties][:time]) > opts[:time]
        }
        log.info "#{features.size} are newer than passed timestamp #{opts[:time].iso8601}"
        if features.any?
          log.info "Last: #{features.last.to_json}"
        end
      end


      {
        type: "FeatureCollection",
        features: features
      }
    end

    protected

    def message(row)

      message = {}
      keys.reject {|k| reject_keys.include? k }.each_with_index do |k, idx|
        if row[idx].to_s != ""
          message[k] = row[idx]
        end
        if message[k] =~ /^\d+$/
          message[k] = message[k].to_i
        elsif message[k] =~ /^\d+\.\d+$/
          message[k] = message[k].to_f
        elsif message[k] =~ /^\d{4}.\d{2}.\d{2}.\d{2}:\d{2}:\d{2}$/
          message[k] = DateTime.parse(message[k]).to_time.utc.iso8601
        end

      end

      if message.key? :gps_fix_attempt and message[:gps_fix_attempt] =~ /Succeeded/i
        message[:technology] = "gps"
        message[:latitude] = message[:gps_latitude]
        message[:longitude] = message[:gps_longitude]
        #message[:time_to_fix] = DateTime.parse(message[:acquisition_time]).to_time - DateTime.parse(message[:acquisition_start_time]).to_time
      else
        message[:technology] = "iridium"
        message[:latitude] = message[:iridium_latitude]
        message[:longitude] = message[:iridium_longitude]
      end
      message[:provider] = "telonics.com"

      message[:platform] =  message[:ctn] || @header[:platform]
      message[:imei] = message[:iridium_imei] || @header[:imei]

      message
    end

    def log
      @log ||= Logger.new(nil)
    end

    def keys
      @keys ||= HEADER.split(",").map {|h| h.downcase.gsub(/\s/, "_").to_sym }
    end

    def keys=keys
      @keys = keys.map {|h| h.downcase.gsub(/\s/, "_").gsub(/[_]+$/, "").to_sym }
    end

    def reject_keys
      @reject_keys ||= REJECT_KEYS
    end

  end
end
