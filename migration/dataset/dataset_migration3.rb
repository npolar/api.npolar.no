module Metadata
  
  # Inject missing organisation id and GCMD short name (used in DIF XML)
  # http://api.npolar.no/dataset/?q=&facets=organisations.id,organisations.name,organisations.gcmd_short_name
  
  # Production
  # 2014-05-06T09:26:43Z http://api.npolar.no/editlog/8be692ea-6b28-4b5e-b947-e56894533c2d
  
  # $ ./bin/npolar-api-migrator /dataset Metadata::DatasetMigration3 --really=false > /dev/null
  class DatasetMigration3
  
    attr_accessor :log
   
    def migrations
      [set_id_and_gcmd_shortname_for_organisations]
    end

    def model
      Metadata::Dataset.new
    end

    def set_id_and_gcmd_shortname_for_organisations
      lambda {|d|
        if d.organisations? and d.organisations.any?
          
          d.organisations.select {|o| o.id.nil? or o.gcmd_short_name.nil? }.each {|o|
            
            if /Norwegian Polar Institute|Norsk Polarinstitutt/ =~ o.name and o[:id] != "npolar.no"
              o[:id] = "npolar.no"
              o[:gcmd_short_name] = "NO/NPI"
              o[:name] = "Norwegian Polar Institute"
  
            elsif "PANGAEA" == o.name
              o[:id] = "pangaea.de"
              o[:gcmd_short_name] = "PANGAEA"
  
            elsif /NSIDC|National Snow an Ice Data Center/ =~ o.name
              o[:id] = "nsidc.org"
              o[:gcmd_short_name] = "NSIDC"
              
            elsif /Department of Geosciences/ =~ o.name and /University of Oslo/ =~ o.name
              o[:id] = "geo.mn.uio.no"
              o[:gcmd_short_name] = "U-OSL/GEO"
              
            elsif /Sysselmannen på Svalbard/ui =~ o.name
              o[:id] = "sysselmannen.no"
              o[:gcmd_short_name] = ""
              
            elsif /University of St. Andrews.*Sea Mammal Research Unit/ =~ o.name
              o[:id] = "smru.st-andrews.ac.uk"
              o[:gcmd_short_name] = "SMRU"
              
            else
              log.warn "#{d.id} organisation missing id or gcmd_short_name: #{o.to_json}"
            end
          }
        end
      d
      }
    end

  end

end