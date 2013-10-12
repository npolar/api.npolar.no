# encoding: utf-8
require "logger"
require "csv"
require "uri"

module Metadata

  # Fix for 184 datasets coming out of the RIS API
  # http://risapi.data.npolar.no/oai?verb=ListIdentifiers&metadataPrefix=dif
  #
  # $ ./bin/npolar_api_migrator http://api:9393/dataset ::Metadata::Dataset ::Metadata::DatasetMigration1 --really=false > /dev/null
  class DatasetMigration1
    include ::Npolar::Api

    attr_writer :log
   
    def migrations
      [fix_people_linking_to_invalid_organisations, force_domain_name_as_organisation, add_past_edits]
    end

    def log
      @log ||= Logger.new(STDERR)
    end

    def select
      lambda {|d| d.to_s =~ /org[.|-]polarresearch\-/ }
    end

    def fix_people_linking_to_invalid_organisations
      [lambda {|d|
        d.people? },
      lambda {|d|
        d.people.select {|p|p.organisation? and not p.organisation.nil?}.map {|p|
          p.organisation = p.organisation.strip
          p.organisation = case p.organisation
            when "gmail.com"
              nil
            when "awi-bremerhaven.de"
              "awi.de"
            when "mail.ustc.edu.cn"
              "ustc.edu.cn"
            when "statkart.no"
              "kartverket.no"
            when "stud.ntnu.no"
              "ntnu.no"
            else p.organisation
          end
        }
        d
      }]
    end
    
    def force_domain_name_as_organisation
      [lambda {|d|
        d.people? or d.organisations? },
      lambda {|d|

        d.people.select {|p| (not p.organisation.nil? and p.organisation !~ URI::regexp)}.map {|p|
          organisation = domain_name_from_name(p.organisation)
          log.debug organisation+" <== "+p.organisation
          p.organisation = organisation
        }
        d
      }]
    end

    def add_past_edits
      filename = File.dirname(__FILE__)+"/../seed/dataset/dataset-editors.csv"
      log.debug filename
      edits = {}
      ::CSV.foreach(filename, {:col_sep => "\t", :return_headers => false}) {|row|
        database_id, email, comment = row[0], row[1], row[3]
        uri = "http://api.npolar.no/dataset/org.polarresearch-#{database_id}"
        uuid = UUIDTools::UUID.sha1_create( UUIDTools::UUID_DNS_NAMESPACE, uri).to_s
        now = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        edits[uuid.to_sym] = { :email => email, :comment => "\nStorage: #{comment}", :edited => now }
      }

      [lambda {|d|
        d.edits? and d.edits.none? },
      lambda {|d|
        if edits.key? d.id.to_sym

        
          edit = edits[d.id.to_sym]
         
          names = (d.people||[]).select {|p|p.email == edit[:email].nil? ? nil : edit[:email] }
          edit[:name] = names.any? ? names[0].first_name+" "+names[0].last_name : ""
  
          d.edits << edit
          d.edits = d.edits.uniq
    
        end

        d
      }]
    end

    protected

    def domain_name_from_name(name)

      case name.strip
        when "University of Innsbruck, Institute of Meteorology and Geophysics"
          "imgi.uibk.ac.at"
        when "University of Bremen, Institute of Environmental Physics (Institut für Umweltphysik)"
          "iup.uni-bremen.de"
        when "University of Tromsø, Norwegian College of Fishery Science (Norges fiskerihøgskole)"
          "nfh.uit.no"
        when "University of Tromsø, Norway"
          "uit.no"
        when "National veterinarian Institute, Regional Laboratory Tromsø (Veterinærinstitutt)"
          "vi.nvh.no"
        when "Norwegian School of Veterinary Science (Norges Veterinærhøgskole)"
          "nvh.no"
        when "University of Oslo, Department of Geosciences"
          "geo.mn.uio.no"
        when "University of Bergen, Geophysical Institute"
          "gfi.uib.no"
        when "University of Bergen"
          "uib.no"
        when "The Norwegian Institute of Food, Fisheries and Aquaculture Research"
          "nofima.no"
        when "Norwegian Meteorological Institute"
          "met.no"
        when "The Geological Survey of Norway (Norges geologiske undersøkelser)"
          "ngu.no"
        when "Finnish Food Safety Authority, Oulu"
          "evira.fi"
        when "University of Oslo, Natural History Museum"
          "nhm.uio.no"
        when "Örebro University, Department of Natural Sciences, MTM Research Centre"
          "mtb.oru.se"
        when "University of Tromsø, Department of Geology"
          "ig.uit.no"
        when "Polish Academy of Sciences, Institute of Oceanology"
          "iopan.gda.pl"
        when "British Geological Survey, NERC Isotope Geosciences Laboratory"
          "nigl.bgs.ac.uk"
        when "University of St. Andrews, Sea Mammal Research Unit"
          "smru.st-andrews.ac.uk"
        else
          ""
      end
    end
  end
end	