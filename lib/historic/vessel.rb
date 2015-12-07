require "hashie/mash"
require "nori"
require "json"
module Historic
class Vessel < Hashie::Mash
    
  include Npolar::Validation::MultiJsonSchemaValidator
  
  def schemas
  	["vessel-1.json"] 
  end
  
  def self.seed(filename_xml="/mnt/public/Datasets/Skipsregister/xml/Skip.xml")
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
          clean_id = v.gsub(/[^a-zA-Z0-9æøåÆØÅ-]/u, "_")
          if clean_id != v
            p "#{v} => #{clean_id}"
            #"Adm.Bra. => Adm_Bra_"
            #"adm.san => adm_san"
            #"earl gr => earl_gr"
            #"fedor l => fedor_l"
            #"fox II => fox_II"
            #"fox III => fox_III"
            #"Frey 1 => Frey_1"
            #"ger ra => ger_ra"
            #"gibr. => gibr_"
            #"gov ru => gov_ru"
            #"gunh. => gunh_"
            #"gus hol => gus_hol"
            #"hans eg => hans_eg"
            #"herku 1 => herku_1"
            #"herku 2 => herku_2"
            #"Hvalr T => Hvalr_T"
            #"Nova Ze1 => Nova_Ze1"
            #"ole&e1 => ole_e1"
            #"jopet 1 => jopet_1"
            #"jopet 2 => jopet_2"
            #"jul th => jul_th"
            #"lady j => lady_j"
            #"mag.tø. => mag_tø_"
            #"nils li => nils_li"
            #"polen Å => polen_Å"
            #"spe & => spe__"
            #"syv.Ham => syv_Ham"
            #"ves møy => ves_møy"
            #"Wil.Bar. => Wil_Bar_"
          end
          v = clean_id
          
        elsif key =~ /_year$/
          v = v.to_i
        elsif key == "harbours"
          if v != "N. N."
            v = v.gsub(/\.$/, "")
          end
          if v =~ /[\/,]/
            v = v.split(/[\/,]/).map {|h| h.strip }
          elsif v =~ /\sog\s/
            v = v.split(" og ").map {|h| h.strip }
          else
            v=[v]
          end
        elsif key == "type"
          v = v.capitalize
        end
        vessel[key] = v
        
        
      end
      vessel["created_by"] = "Kjell-G. Kjær"
      vessel["created"] = dataroot["@generated"]+"Z"
      
      vessel
    }
  end
  
  def self.save_seed(filename_seed = "#{__dir__}/../../seed/vessel/vessel.json")
    File.open(filename_seed, "w") {|f| f.write(JSON.pretty_generate(seed))}
  end
  
end
end
