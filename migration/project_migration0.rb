# encoding: utf-8
require "logger"
require "uri"
# Migrates projects to schema version 1.0 
# $ ./bin/npolar_api_migrator http://localhost:9393/project ::Project ::ProjectMigration0 --really=false > /dev/null

class ProjectMigration0

  attr_writer :log
 
  def migrations
    [fix_schema, force_domain_name_in_people_organisations, fix_people_linking_to_wrong_organisations]
  end

  def select
    lambda {|d| d.schema == "http://api.npolar.no/schema/project.json" }
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
      [lambda {|d|
        d.people? and d.people.any? },
      lambda {|d|

        d.people.select {|p| (not p.organisation.nil? and p.organisation !~ URI::regexp)}.map {|p|

          if p.email =~ /@/ 
            organisation = p.email.split("@")[1]
          else
            organisation = domain_name_from_name(p.organisation)
          end
          log.debug organisation+" <== "+p.organisation
          p.organisation = organisation
        }
        d
      }]
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
end