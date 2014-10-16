require "hashie/mash"
require "nori"
require "json"

class Vessel < Hashie::Mash
  
  def self.seed(filename_xml="#{__dir__}/../seed/vessel/Skip.xml")
    nori = Nori.new
    dataroot = nori.parse(File.read(filename_xml))["dataroot"]
                                                               
    dataroot["Skip"].map {|v|
      vessel = {}
      v.each do |k,v|
        key = case k
          when "Hovednavn" then "name"
          when "Hovedreder" then "owner"
          when "Tilhørighet" then "harbours"
          when "Byggeår" then "built_year"
          when "Byggested" then "built_where"
          when "Bildereferanse" then "caption"
          when "Skipsreferanse" then "sources"
          when "Utrustning" then "description"
          when "Historikk" then "history"
          when "Forlist_x0020_år" then "shipwrecked_year"
          when "Forlist_x0020_sted" then "shipwrecked_location"
          else k.downcase
        end
        if key == "id"
          v = v.gsub(/\s\.\"/, "_")
        elsif key =~ /_year$/
          v = v.to_i
        elsif key == "harbours"
          if v =~ /\//
            v = v.split("/").map {|h| h.strip}
          else
            v=[v]
          end
        end
        vessel[key] = v
        
        
      end
      vessel["created_by"] = "Kjell Gudmund Kjær"
      vessel["created"] = dataroot["@generated"]
      vessel["alpha"] = vessel["name"][0].upcase
      vessel
    }
  end
  
  def self.save_seed(filename_seed = "#{__dir__}/../seed/vessel/vessels.json")
    File.open(filename_seed, "w") {|f| f.write seed.to_json}
  end
  
end
