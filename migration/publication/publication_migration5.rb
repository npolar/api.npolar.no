# encoding: utf-8
require 'nokogiri'
require 'date'
require 'time'

# $ ./bin/npolar-api-migrator /publication ::PublicationMigration5 --really=false > /dev/null

# Migrate to http://api.npolar.no/schema/publication-1 (from versionless)
# * Remove XML entities
# * Added license
# * DOI as string
# * abstract (i18n) <- scientific_abstract
# * overview (i18n) <- summary

class PublicationMigration5

  attr_accessor :log

  def migrations
    [unescape_xml_entitites, rename, force_schema,
      doi, force_originator_role_for_organisations_without_any_role,
      i18n_abstract_and_overview]
  end
  
  def model
    Publication.new
  end
  
  # doi as text field
  # "doi": "10.1126/science.1141038"
  # http://dx.doi.org/10.1126/science.1141038 
  def doi
    lambda {|d|
      if d.links? and not d.doi
        dois = d.links.select {|l| l["rel"] =~ /doi/i }
        if dois.any?
          doi = dois.first["href"]
          if doi =~ /http:\/\/(dx\.)?doi\.org\/10\./ 
            d.doi = "10."+doi.split('10.')[1]
          elsif doi =~ /10\./
            d.doi = "10."+doi.split('10.')[1]
          elsif dois.first["title"] =~ /10\./
            d.doi = "10."+dois.first["title"].split('10.')[1]
          else
            log.info d.id + " Bad DOI"+ dois.to_json
          end
          
          # Keep link for backwards compatability
          # d.links = d.links.reject {|l| l["rel"] =~ /doi/i }
          #log.info d.doi
        end
      end
      
    d
    }
  end
  
  # Organisations: publisher is only role in use
  def force_originator_role_for_organisations_without_any_role
    lambda {|d|
      if d.organisations? and d.organisations.any?
        d.organisations = d.organisations.map {|o|
          if o.roles.nil? or o.roles == []
            o.roles = ["originator"]
          end
          o
        }
        #log.info d.organisations.to_json
      end
      
      d
    }
  end

  def rename
    lambda {|d|
      if not d.published? and d.published_sort?
        #log.warn d.published_helper
        if d.published_sort.nil?
          d.published_sort = ""
        end
        
        d.published = Time.parse(d.published_sort).strftime(d.published_helper)
        #log.info "#{d.published} #{d.published_sort} #{d.published_helper}"
      end
      d.delete :published_sort
      d.delete :published_helper
      
      # attachments_access: no (1565) yes (189) null (3295)      
      if d.attachments_access?
        if not d.license?
          d.license = case d.attachments_access
            when "yes" then "http://creativecommons.org/licenses/by/4.0/"
            else nil
          end
        end
        d.delete :attachments_access
      end
      
      #messy
      #if d.journal?  
      #  if d.journal.np_series?
      #    if d.journal.np_series =~ /other/i
      #      d.journal.name = d.journal.series
      #    else
      #      d.journal.name = d.journal.np_series
      #    end
      #    
      #    d.journal.delete :np_series
      #    
      #    d.volume = d.journal.series_no
      #    d.journal.delete :series_no
      #    
      #    log.debug d.journal.to_json
      #    
      #  end
      #  
      #  if d.journal.series_no
      #
      #  end
      #end
      
      # draft yes (110)
      # year-published_sort 1997 (1) 2001 (1) 2004 (1) 2007 (1) 2008 (1) 2010 (1) 2011 (2) 2012 (1) 2013 (4) 2014 (42) 2015 (17)
      # state published (55) submitted (49) accepted (6)
      #if d.draft?
      #  d.delete :draft
      #end
      d
    }
  end
  
  def force_schema
    lambda {|d|
      d.schema = "http://api.npolar.no/schema/publication-1"
      if not d.topics?
        d.topics = ["other"]
      end
      if not d.locations?
        d.locations = []
      end
      if not d.topics?
        d.topics = []
      end
      d.delete :edits
      d.delete :base
      
      d
    }
  end
  
  def i18n_abstract_and_overview
    lambda {|d|
      d.abstract = [{"@value": d.scientific_abstract, "@language": "en"}]
      d.overview = [{"@value": d.norw_summary, "@language": "nb"}]
      
      d.delete :scientific_abstract
      d.delete :norw_summary
      
      d
    }
  end
    
  def unescape_xml_entitites
    lambda {|d|
      
      d.keys.each do |k|
        if d[k].is_a? String
          d[k] = Nokogiri::XML.fragment(d[k]).text
        end
      end

      d.tags = (d.tags||[]).map {|t| Nokogiri::XML.fragment(t).text }

      # All fixed?
      xml_entity = /[&][#]x([0-9a-f][0-9a-f]);/ui
      if d.to_json =~ xml_entity
        raise  d.to_json
      end
      
      d
    }
  end
  
end