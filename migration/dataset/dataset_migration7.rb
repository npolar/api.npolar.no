require "logger"

module Metadata

  # Schema 1.0.0.pre
  # Wash GCMD Short Name, see http://gcmdservices.gsfc.nasa.gov/static/kms/providers/providers.csv and http://api.npolar.no/gcmd/concept/?q=norway&filter-concept=providers&facet-size=100&limit=100
  # Homepage for organisations (not links per role)
  
  # Production: "2014-05-20T08:26:53Z"
  # http://api.npolar.no/editlog/961457c6-b582-4c93-925a-0b69d67c51fb
  
  # $ ./bin/npolar-api-migrator /dataset ::Metadata::DatasetMigration7 --really=false > /dev/null
  class DatasetMigration7
     
    # dataset id, org id, gcmd provider, homepage, name
    @@fixes = [
    [
        "025b82e5-4a5a-558f-b021-17c1a60f0922",
        "geo.su.se",
        "SU/GEOL",
        "http://www.geo.su.se/",
        "Stockholm University"
    ],
    [
        "0cd3e54a-3f15-44a4-ba01-9ed39624c59b",
        "sysselmannen.no",
        nil,
        "http://sysselmannen.no",
        "Sysselmannen på Svalbard"
    ],
    [
        "1d055aa0-803b-5357-97e4-6fe7af66b244",
        "uit.no",
        "U-TROMSO/NCFS", # wrong but what can you do "UiT",
        "http://uit.no",
        "University of Tromsø, Department of Geology"
    ],
    [
        "1e29fe0a-2eb8-48d1-8841-2415e53139be",
        "sysselmannen.no",
        nil,
        "http://sysselmannen.no",
        "Sysselmannen på Svalbard"
    ],
    [
        "28ecb60f-f355-53f6-b2c9-a120df205242",
        "igf.edu.pl",
        "PL/PAS/IGF", #"IGF PAS",
        "http://igf.edu.pl/en",
        "Polish Academy of Sciences, Institute of Geophysics"
    ],
    [
        "2cc972c4-08d4-5ea9-aa0c-fea4ed6e2bb8",
        "isac.cnr.it",
        nil, #"CNR-ISAC",
        "http://isac.cnr.it",
        "National Research Council of Italy, Institute of Atmospheric Sciences and Climate"
    ],
    [
        "3430df6a-7189-40ce-a1e4-67a4f765e767",
        "dirmin.no",
        nil,
        "http://www.dirmin.no/svalbard/Norsk/informasjon/Sider/Bergmesteren%20for%20Svalbard.aspx",
        "Direktoratet for mineralforvaltning med Bergmesteren for Svalbard"
    ],
    [
        "41901a60-5341-52b5-8310-e548ca6ccfad",
        "nmbu.no",
        nil, ##"VETHS",
        "http://nvh.no/no/Forskning/Forskningsgrupper/Seksjon-for-Arktisk-Veterinarmedisin---SAV/",
        "Norwegian School of Veterinary Science (Norges Veterinærhogskole), Department of Arctic Veterinary Medicine"
    ],
    [
        "4690bbef-9618-5a2b-bdd1-7f6b4fc50da7",
        "uit.no",
        "U-TROMSO/NCFS", #"UiT BFE",
        "http://www2.uit.no/ikbViewer/page/ansatte/organisasjon/hjem?p_dimension_id=88163&p_menu=42374&p_lang=1",
        "University of Tromsø, Faculty for Biosciences, Fisheries and Economics"
    ],
    [
        "4b2e20aa-3839-47b0-a76e-9d0cc8bedc7c",
        "sysselmannen.no",
        nil,
        "http://sysselmannen.no",
        "Sysselmannen på Svalbard"
    ],
    [
        "4b38a742-0b00-515c-b6bd-9d5df34d2701",
        "nina.no",
        "NO/NINA", #"NINA-Tromsø",
        "http://nina.no",
        "Norwegian Institute for Nature Research, Tromsø"
    ],
    [
        "59102277-1e3d-42af-97de-fc2f49e2f203",
        "spacecentre.no",
        nil,
        "http://spacecentre.no",
        "The Norwegian Space Centre"
    ],
    [
        "612d385a-4342-5103-bb74-08f574433928",
        "museumstavanger.no",
        nil,
        "http://www.museumstavanger.no/museums/stavanger-museum-natural-history-/bird-ringing-centre/",
        "Ringing Centre at Stavanger Museum"
    ],
    [
        "630e034b-1fc6-5d79-8241-784b86bdec40",
        "uit.no",
        "U-TROMSO/NCFS", #"UiT BFE",
        "http://www2.uit.no/ikbViewer/page/ansatte/organisasjon/hjem?p_dimension_id=88163&p_menu=42374&p_lang=1",
        "University of Tromsø, Faculty for Biosciences, Fisheries and Economics"
    ],
    [
        "6d453561-8e66-53a0-9a1c-46c7aac614ce",
        "geo.mn.uio.no",
        "U-OSLO/GEO",
        "http://geo.mn.uio.no",
        "Department of Geosciences, University of Oslo, Norway"
    ],
    [
        "7398aeb0-1e50-5ef4-a059-c906ae76bf6b",
        "kartverket.no",
        "NO/NMA",#"STATKART",
        "http://kartverket.no",
        "Norwegian Mapping Authority (Statens Kartverk), Norwegian Hydrographic Service (Sjøkartverket)"
    ],
    [
        "79c539d0-c67c-5ae1-a973-ce282fe46abf",
        "uef.fi",
        nil, #"UEF",
        "http://uef.fi/biologia",
        "University of Eastern Finland, Faculty of Biosciences, (Joensuun Yliopisto)"
    ],
    [
        "79e5e829-cb29-57ec-a101-45523c01a650",
        "uit.no",
        nil,
        "http://uit.no",
        "University of Tromsø"
    ],
    [
        "7c488548-fb51-5ab4-83ad-5e4b6696fa61",
        "nmbu.no",
        nil, #"VETHS",
        "http://nvh.no",
        "Norwegian School of Veterinary Science (Norges Veterinærhøgskole)"
    ],
    [
        "7c5ee27d-b7fd-4309-af82-77754b0ba9a0",
        "sysselmannen.no",
        nil,
        "http://sysselmannen.no",
        "Sysselmannen på Svalbard"
    ],
    [
        "89f430f8-862f-11e2-8036-005056ad0004",
        "npolar.no",
        "NO/NPI",
        "http://npolar.no",
        "Norwegian Polar Institute"
    ],
    [
        "89f430f8-862f-11e2-8036-005056ad0004",
        "geo.mn.uio.no",
        "U-OSLO/GEO",
        "http://geo.mn.uio.no",
        "Department of Geosciences, University of Oslo, Norway"
    ],
    [
        "926d599e-38ea-546e-9e69-bfc731691d3c",
        "sysselmannen.no",
        nil,
        "http://sysselmannen.no",
        "Sysselmannen på Svalbard"
    ],
    [
        "9a51de6d-9a15-5945-bba1-091e26b7fcb9",
        "miljodirektoratet.no",
        nil,
        "http://www.miljodirektoratet.no",
        "Miljødirektoratet [Norwegian Environment Agency]"
    ],
    [
        "a9c97694-d2c9-5429-a639-3e7db089820e",
        "awi.de",
        "AWI",#"AWI-Bremerhaven",
        "http://awi.de/en/institute/sites/bremerhaven",
        "Alfred Wegener Institute Bremerhaven"
    ],
    [
        "bb50cf85-04ce-554c-8715-09a7a3234978",
        "kartverket.no",
        "NO/NMA", #"STATKART",
        "http://kartverket.no",
        "Norwegian Mapping Authority (Statens Kartverk)"
    ],
    [
        "bb9467d6-d04e-522e-aee1-0dae78ad65b6",
        "uit.no",
        "U-TROMSO/NCFS", #"UiT NFH",
        "http://nfh.uit.no/index.aspx",
        "University of Tromsø, Norwegian College of Fishery Science (Norges fiskerihøgskole)"
    ],
    [
        "c5c455cc-bd6e-53de-afa7-e5fdeee6571e",
        "awi.de",
        "AWI", #-Bremerhaven",
        "http://awi.de/en/institute/sites/bremerhaven",
        "Alfred Wegener Institute Bremerhaven"
    ],
    [
        "d4a8dce8-c168-5e15-a210-73c0cfa05e3f",
        "oru.se",
        nil, #"ORU MTM",
        "http://oru.se/Forskning/Forskningsmiljoer/miljo/MTM",
        "Örebro University, Department of Natural Sciences, MTM Research Centre"
    ],
    [
        "eaa0b8f5-bbe4-59ce-8d19-01b4a342e823",
        "loff.biz",
        nil,#"LoFF",
        "http://loff.biz",
        "Longyearbyen Feltbiologiske Forening"
    ],
    [
        "f6feca82-8d8c-56e5-8db1-f68691e777ec",
        "geo.uu.se",
        "UPPSALA/GEO",##"UU-ES",
        "http://www.geo.uu.se",
        "Uppsala University, Department of Earth Sciences"
    ],
    [
        "f6feca82-8d8c-56e5-8db1-f68691e777ec",
        "ceh.ac.uk",
        nil, #"CEH",
        "http://www.ceh.ac.uk/",
        "Centre for Ecology and Hydrology, Bangor"
    ],
    [
        "f6feca82-8d8c-56e5-8db1-f68691e777ec",
        "uibk.ac.at",
        nil,#"UIBK",
        "http://www.uibk.ac.at/",
        "University of Innsbruck, Austria"
    ],
    [
        "f6feca82-8d8c-56e5-8db1-f68691e777ec",
        "bgs.ac.uk",
        "BGS",#"BGS NIGL",
        "http://bgs.ac.uk/",
        "British Geological Survey, NERC Isotope Geosciences Laboratory"
    ],
    [
        "f6feca82-8d8c-56e5-8db1-f68691e777ec",
        "shef.ac.uk",
        nil, #"SHEF",
        "https://www.sheffield.ac.uk/",
        "University of Sheffield, United Kingdom"
    ]
    ]
    
    attr_accessor :log
       
    def migrations
      [schema_100_pre, set_org_homepage_and_delete_links, gcmd_short_name_and_homepage]
    end
    
    def model
      ::Metadata::Dataset.new
    end
        
    def schema_100_pre
      lambda {|d|
        d.schema = "http://api.npolar.no/schema/dataset-1-0.0.pre"
        d
      }
    end
    
    def select
      lambda {|d| d.id == "7398aeb0-1e50-5ef4-a059-c906ae76bf6b"}
    end
    
    def gcmd_short_name_and_homepage
      lambda {|d|
        @@fixes.select {|f|f[0] == d.id}.each do |fix|
          
          d.organisations.select {|o| o.name == fix[4] }.each do |o|
            o.id = fix[1]
            o.gcmd_short_name = fix[2]
            o.homepage = fix[3]
            log.info o.to_json
          end
        end
        d
      }
    end
    
    def set_org_homepage_and_delete_links
      lambda {|d|
        
        if d.organisations? and d.organisations.any?
          d.organisations.select {|o| o.links? and o.links.any? }.each do |o|
            o.homepage = o.links.map {|l| l.href }.flatten.uniq.reject {|href| href =~ /http\:\/\/data\.npolar\.no/ }.first
            o.delete :links        
          end
        else
          log.warn "No organisations with links: #{d.id} #{d.title}"
        end
        
        d
      }
    end
    
  end
end