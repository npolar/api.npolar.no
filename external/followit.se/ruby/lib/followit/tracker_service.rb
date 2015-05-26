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
    
    # Login
    # Get (tracker ids)
    # For each tracker id
    #   GetTrafficDates
    #     For each traffic date
    #       GetUnitReportPositions
    #         For each unit report
    #            Valid?
    #              Yes: Save if updated
    #              No: Log error 
    #            
    def download(destination, days=nil)
      if auth.nil?
        raise ArgumentError, "Please set auth -> Followit::AuthService"
      end
      log.debug "Starting #{auth.username} download of Followit XML to #{destination} [#{ days.nil? ? '': "last #{days} day(s)"}]"
      auth.login
      
      tracker_ids = get_tracker_ids
      log.debug "Trackers for #{auth.username} (#{tracker_ids.size}): #{tracker_ids.to_json}"
      
      tracker_ids.each_with_index {|id, idx|
        
        if idx > 0 and not auth.nil?
          # login again (to avoid session to expires)
          auth.login
        end
        log.debug "Tracker: #{id}"
     
        
        get_traffic_dates(id, days).each {| dt |
          begin
            year = dt.year
            from,to = date_from_to(dt)
            date = dt.to_date.to_s
            
            folder = "#{destination}/#{year}/#{id}"
            FileUtils.mkdir_p(folder)
            filename = "#{folder}/followit-tracker-#{id}-#{date}.xml"

            positions = get_unit_report_positions(id, from, to)            
            new_sha1 = Digest::SHA1.hexdigest(positions.to_xml)
            
            if valid_positions? positions
              if File.exists? filename
                existing_sha1 = Digest::SHA1.file(filename).hexdigest
                if new_sha1 != existing_sha1
                  File.open(filename, "wb") { |file| file.write(positions.to_xml)}
                  log.debug "Updated: #{filename}"
                else
                  log.debug "Keeping existing #{filename}"
                end
                
              else
                File.open(filename, "wb") { |file| file.write(positions.to_xml)}
                log.debug "Validated and saved new data: #{filename}"
              end
                          
            else
              log.error "Invalid unit positions: #{positions}"
            end
          rescue => e
            log.fatal "Failed downloading followit.se #{dt.to_date} data for tracker #{id}: #{e}"
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
      extract(execute(request(get_tracker_ids_envelope)), xpath).sort
    end
    
    def get_traffic_dates(tracker_id, days=nil)
      traffic_dates = extract(execute(request(get_traffic_dates_envelope(tracker_id))), "//followit:GetTrafficDatesResult/followit:dateTime").map {|dt|
        DateTime.parse(dt) 
      }.sort.reverse
      if days.nil?
        traffic_dates
      else
        days = days.to_i.abs-1
        if days < 0
          raise ArgumentError, "Please provide a positive integer >= 1 for the number of days to download"
        end
        min_date = ((traffic_dates[0].to_date) - days )
        traffic_dates.reject {|dt| dt < min_date }
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
    
    def valid_positions? positions
      xpath("//followit:UnitReportPosition").size > 0
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