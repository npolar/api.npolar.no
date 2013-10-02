# encoding: utf-8
require "logger"
require "uri"
require "csv"
# Migrates projects to schema version 1.0 
# $ ./bin/npolar_api_migrator http://localhost:9393/project ::Project ::ProjectMigration0 --really=false > /dev/null

class ProjectMigration0

  attr_writer :log

  def initialize
    @organisation = data_centers_from_ris
  end
 
  def migrations
    [fix_schema, force_domain_name_in_people_organisations,fix_organisations, fix_people_linking_to_wrong_organisations]
  end

  def select
    lambda {|d| not d.schema or d.schema == "http://api.npolar.no/schema/project.json" }
  end

  def log
    @log ||= Logger.new(STDERR)
  end

  def fix_schema
      [lambda {|d|
        d.schema == "http://api.npolar.no/schema/project.json" },
      lambda {|d|
        d.schema = "http://api.npolar.no/schema/project"
        d
      }]
  end

  def fix_people_linking_to_wrong_organisations
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

  def force_domain_name_in_people_organisations
      orgs = []
      [lambda {|d|
        d.people? and d.people.any? },
      lambda {|d|
        d.people.select {|p| (not p.organisation.nil? and p.organisation !~ URI::regexp)}.map {|p|

          if p.email =~ /@/ 
            organisation = p.email.split("@")[1]
          else
            organisation = domain_name_from_name(p.organisation)
          end

          if organisation.to_s.empty? 
            orgs << p.organisation
            #log.debug p.organisation #organisation+" <== "+p.organisation
          end
          p.organisation = organisation
        }
        log.debug orgs.uniq
        d
      }]

  end

  def fix_organisations
      orgs = []
      [
        lambda {|d|
          d.organisations? and d.organisations.any? 
        },
        lambda {|d|
          #log.debug d.organisations
          orgs += d.organisations
          log.debug orgs.uniq
          d
        }
      ]
  end

  protected

  def domain_name_from_name(name)
    domain = case name
      when /(Norwegian Polar Institute|Norsk Polarinstitutt)/i
        "npolar.no"
      when /Akvaplan-Niva/i
        "akvaplan.niva.no"
      else ""
    end
  end

  def data_centers_from_ris
    filename = File.dirname(__FILE__)+"/../seed/organisation/md_data_center.tsv"
    dc = {}
    ::CSV.foreach(filename, {:col_sep => "\t", :return_headers => false}) {|row|
      log.debug row
    }
    dc
  end
end
