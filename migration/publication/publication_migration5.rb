# encoding: utf-8
require 'nokogiri'
require 'date'
require 'time'

# $ ./bin/npolar-api-migrator /publication ::PublicationMigration5 --really=false > /dev/null

# Migrate to http://api.npolar.no/schema/publication-2
# * Remove XML entities
# * Topics cleanup (no mixed topics)
# * Added "authors" and "contributors" (and removed "people")
# * Added license
# * Removed draft, it's covered in state = submitted
# * DOI now string (removed from links)

# @todo
# journal object
# publication object, with pages object, doi string?
# "abstract" => i18n
# "norw_summary": => i18n
# license
class PublicationMigration5

  attr_accessor :log

  def migrations
    [unescape_xml_entitites, rename, force, paleo, toxicology, split_biogeochemistry,
      doi, authors_and_contribs, force_originator_role_for_organisations_without_any_role]
  end
  
  def model
    Publication.new
  end
  
  # author (4918) editor (548) co-author (20) translator (4)
  def authors_and_contribs
    lambda {|d|
      if d.people? and d.people.any?
        d.authors = d.people.select {|p|
          if p.roles.nil?
            p.roles = ["editor"]
          end
          
          if p.roles.none?
            raise d.to_json
          end

          p.roles.include? 'author' }.map {|a|
          a = a.reject {|k,v| k == 'roles'}
          a
        }
        d.contributors = d.people.select {|p| p.roles.any? {|r| r != 'author'} }.map {|c|
          if c.roles.size > 1
            raise c.to_json 
          end
          #log.info c.to_json
          c
        } 
        
      end
      d.delete :people
      if (d.authors.nil? or d.authors.none?) and (d.contributors.nil? or d.contributors.none?)
        log.warn "#{d.id} #{d.title}"
      end
      
      
      d
    }
  end
  
  # doi field
  # "doi": "10.1126/science.1141038"
  # http://dx.doi.org/10.1126/science.1141038 
  def doi
    lambda {|d|
      if d.links? #and not d.doi
        dois = d.links.select {|l| l["rel"] =~ /doi/i }
        if dois.any?
          doi = dois.first["href"]
          if doi =~ /http:\/\/(dx\.)?doi\.org\/10\./ 
            d.doi = "10."+doi.split('10.')[1]
          elsif doi =~ /10\./
            d.doi = "10."+doi.split('10.')[1]
          else
            log.info d.id + " Bad DOI"+ dois.to_json
          end
          d.links = d.links.reject {|l| l["rel"] =~ /doi/i }
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
       
        #log.info d.published
      end
      d.delete :published_sort
      d.delete :published_helper
      
      if d.tags? and not d.keywords?
         d.keywords = d.tags
         d.delete :tags
      end
      d.delete :tags
      
      if not d.license and d.attachments_access?
        d.license = case d.attachments_access
        when "yes" then "http://creativecommons.org/licenses/by/4.0/"
        else nil
        end
        d.delete :attachments_access
      end
        
      
      # attachments_access: no (1565) yes (189) null (3295)
      # attachment_access !? => license!
      
      # Removing draft, since it's covering the same aspect as state=submitted
      
      # draft yes (110)
      # year-published_sort 1997 (1) 2001 (1) 2004 (1) 2007 (1) 2008 (1) 2010 (1) 2011 (2) 2012 (1) 2013 (4) 2014 (42) 2015 (17)
      # state published (55) submitted (49) accepted (6)
      
      if d.draft?
        d.delete :draft
      end
      d
    }
  end
  
  # split biogeochemistry
  def split_biogeochemistry
    lambda {|d|
      if d.topics.include? "biogeochemistry"
        d.topics = d.topics.reject {|t| ["biology", "geology", "chemistry", "biogeochemistry"].include? t }
        d.topics << "biology"
        d.topics << "geology"
        d.topics << "chemistry"
      end
    d
    }
  end
  
  # cartography <= maps|topography 
  def cartography
    lambda {|d|
      if d.topics.include? "maps" or d.topics.include? "topography"
        d.topics = d.topics.reject {|t| ["maps", "topography"].include? t }
        d.topics << "cartography"
      end
    d
    }
  end
  
  # paleo + climate <= paleoclimate
  def paleo
    lambda {|d|
      if d.topics.include? "paleoclimate"
        d.topics = d.topics.reject {|t| ["paleo", "climate", "paleoclimate"].include? t }
        d.topics << "paleo"
        d.topics << "climate"
      end
      d
    }
  end
  
  def toxicology
    lambda {|d|
      if d.topics.include? "ecotoxicology"
        d.topics = d.topics.reject {|t| ["ecotoxicology", "toxicology"].include? t }
        d.topics << "toxicology"
      end
      d
    }
  end
  
  def force
    lambda {|d|
      d.schema = "http://api.npolar.no/schema/publication-2##{Time.now.utc.to_date}"
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