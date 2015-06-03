require "typhoeus"
require "nokogiri"
require "time"
require "json"
require "fileutils"
require "logger"
require "digest"

module Followit
  
  class TrackerService
    
    attr_accessor :auth
    
    include Soap
    
    URI = "http://total.followit.se/DataAccess/TrackerService.asmx"
    
    # Download tracks for a user to disk (organised by year and month)
    #
    # Login
    # Get (tracker ids)
    # For each tracker id
    #   GetTrafficDates
    #     Reduce to unique months
    #       GetUnitReportPositions
    #         Save if valid
    #            
    def download(destination, earliest=nil)
      if auth.nil?
        raise ArgumentError, "Please set auth -> Followit::AuthService"
      end
      log.debug "Starting #{auth.username} download of Followit XML to #{destination} [#{ earliest.nil? ? '': "earliest date: #{earliest.to_date}"}]"
      auth.login
      
      tracker_ids = get_tracker_ids
      log.debug "Trackers for #{auth.username} (#{tracker_ids.size}): #{tracker_ids.to_json}"
      
      tracker_ids.each_with_index {|id, idx|
        
        if idx > 0 and not auth.nil?
          # login again (to avoid session to expires)
          auth.login
        end
        # log.debug "Tracker: #{id}"
     
        get_traffic_dates(id, earliest).map {|dt|
          d = dt.to_date
          DateTime.new(d.year, d.month)
          }.uniq.each {| dt |
          begin
          
            year = dt.year
            date_from = Date.new(dt.year, dt.month)
            date_to = date_from >> 1
            month_text = date_from.month.to_s.gsub(/-01$/, "").rjust(2, "0")
            
            folder = "#{destination}/#{year}/#{year}-#{month_text}"
            FileUtils.mkdir_p(folder)
            filename = "#{folder}/followit-#{year}-#{month_text}-tracker-#{id}.xml"
            
            from = dt.to_time.utc.iso8601
            to = DateTime.parse(date_to.to_s).to_time.utc.iso8601
          
            positions = get_unit_report_positions(id, from, to)
            
            new_sha1 = Digest::SHA1.hexdigest(positions.to_xml)
            
            if valid_positions? positions, filename
              if File.exists? filename
                existing_sha1 = Digest::SHA1.file(filename).hexdigest
                
    
                
                if new_sha1 != existing_sha1
                  
                  existing_count = Nokogiri::XML(positions.to_xml).xpath("count(//followit:UnitReportPosition)", { followit: Followit::Soap::NAMESPACE })
                                    
                  if existing_count.to_i != @count
  
                    File.open(filename, "wb") { |file| file.write(positions.to_xml)}
                    log.warn "Updated: #{filename}"
                  end
                else
                  # log.debug "Keeping existing #{filename}"
                end
                
              else
                File.open(filename, "wb") { |file| file.write(positions.to_xml)}
                log.debug "Validated and saved new data: #{filename}"
              end
                          
            else
              log.error "Invalid unit positions: #{positions}"
            end
          rescue => e
            log.fatal "Failed downloading followit.se #{year}-#{month_text} data for tracker #{id}: #{e}"
          end
        }
      }
      log.debug "Finished #{auth.username} Followit XML download"
      
    end
    
    def get_tracker_ids
      get_trackers("//followit:GetResult/followit:Tracker/followit:TrackerId").map {|t|
        t.content
      }.sort
    end
    
    def get_trackers(xpath="//followit:GetResult/followit:Tracker")
      extract(get, xpath).sort      
    end
    
    def get_trackers_array
      document = Nokogiri::XML(get.body)
      template = Nokogiri::XSLT(File.read(File.join(__dir__, "..", "..", "..", "xslt", "followit-trackers.xslt")))
      JSON.parse(template.apply_to(document)) # https://github.com/sparklemotion/nokogiri/issues/247
    end
    
    def get
      execute(request(get_tracker_ids_envelope))
    end
    
    def get_traffic_dates(tracker_id, earliest=nil)
      traffic_dates = extract(execute(request(get_traffic_dates_envelope(tracker_id))), "//followit:GetTrafficDatesResult/followit:dateTime").map {|dt|
        DateTime.parse(dt) 
      }.sort.reverse
      if earliest.nil?
        traffic_dates
      else
        traffic_dates.reject {|dt| dt < earliest }
      end
      
    end
    
    def traffic_dates(tracker_id, &block)
      response = execute(request(get_traffic_dates_envelope(tracker_id)))
      if block_given?
        block.call(response.body)
      else
        response
      end
    end
    
    def get_traffic_dates_for_all_trackers(ids=nil, &block)
      dates = {}
      ids = ids.nil? ? get_tracker_ids : ids
      
      ids.each {|id|
        dates[id] = get_traffic_dates(id)
      }
      dates
    end
        
    def get_unit_report_positions(tracker_id, from="1900-01-01T00:00:00Z", to="2100-01-01T00:00:00Z")
      extract(execute(request(get_unit_report_positions_envelope(tracker_id, from, to))), "/soap:Envelope")
    end
    
    def positions_from_xml(xml)
      if File.exists? xml
        log.debug "Creating JSON from XML file #{xml}"
        xml = File.read(xml)
      end
      document = Nokogiri::XML(xml)
      template = Nokogiri::XSLT(File.read(File.join(__dir__, "..", "..", "..", "xslt", "followit-json.xslt")))
      JSON.parse(template.apply_to(document)) # https://github.com/sparklemotion/nokogiri/issues/247
    end
    
    def valid_positions? (positions, f=nil)
      @count = xpath("count(//followit:UnitReportPosition)").to_i
      log.debug "#{@count} positions [#{File.basename(f)}]"
      @count > 0
    end
    
    protected
    
    #<Get xmlns="http://tempuri.org/">
    #  <queryData>
    #    <Filter>%%</Filter>
    #    <Top>1000</Top>
    #  </queryData>
    #</Get>
    def get_tracker_ids_envelope(filter="%%", top=1000)
      envelope do |xml|
        xml.Get(xmlns: NAMESPACE) do
          xml.queryData do
            xml.Filter filter
            xml.Top top
          end
        end
      end
    end
    
    def get_unit_report_positions_envelope(tracker_id, from, to)
      envelope do |xml|
        xml.GetUnitReportPositions(xmlns: NAMESPACE) do
          xml.trackerId tracker_id
          xml.fromDate from
          xml.toDate to
        end
      end
    end
    
    def get_traffic_dates_envelope(tracker_id)
      envelope do |xml|
        xml.GetTrafficDates(xmlns: NAMESPACE) do
          xml.trackerId tracker_id
        end
      end
    end
     
  end
end