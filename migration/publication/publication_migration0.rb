# encoding: utf-8
require_relative "../../lib/publication"

# $ ./bin/npolar-api-migrator http://api:9393/publication PublicationMigration0 --really=false > /dev/null 2> /mnt/felles/Midlertidig/Conrad/publication-migration-0-ch.log
# $ ./bin/npolar-api-migrator /publication PublicationMigration0 --really=false > /dev/null 2> /mnt/felles/Midlertidig/Conrad/publication-migration-0-production.log
# In production: 2014-04-10
class PublicationMigration0

  attr_accessor :log

  def migrations
    [simple_fixes, fix_invalid_links, locations_as_object]
  end

  def model
    Publication.new
  end
  
  #def select
  #  lambda {|d| d.locations? and d.locations.any?}
  #end
  
  def fix_invalid_links
    @@broken=[]
    lambda {|d|

      if d.links? and d.links.any? 
        d.links = d.links.map {|l|
          
          if l.href !~ /^http/ui
            @@broken << [ "http://api.npolar.no/publication/#{d.id}", l, @@broken.size]
            log.fatal l.href.to_json
            
            l.title = "#{l.title} | #{l.href}"
            l.href = "http://api.npolar.no/bad-href"
            l
            
          end
          l
        }
        
      end
      d
    }
  end
  
  # Schema, publication_lang, delete review_progress
  def simple_fixes
    lambda {|d|
      
      d.schema = "http://api.npolar.no/schema/publication-1.0-rc3"
      unless d.publication_lang?
        d.publication_lang = d.original_lang ||= ""
        d.delete :original_lang
      end
      if d.review_progress?
        d.delete :review_progress
      end
      d
    }
  end
    
  def locations_as_object
    lambda {|d|

      if d.locations? and d.locations.any? and d.locations.all? {|l| l.is_a? String }
        log.info d.title.to_json
        log.info d.locations
         
        if d.title =~ /Svalbard/ui and d.title !~ /North of Svalbard/ui and d.locations.none? {|l| l =~ /Svalbard/}
          log.warn "[+] Svalbard"
          d.locations << "The Arctic - Svalbard"
        elsif d.title =~ /Spitsbergen/ui and d.locations.none? {|l| l =~ /Spitsbergen/}
          log.warn "[+] Spitsbergen"
          d.locations << "The Arctic - Svalbard - Spitsbergen"
        elsif d.title =~ /Jan Mayen/ui and d.locations.none? {|l| l =~ /Jan Mayen/}
          log.warn "[+] Jan Mayen"
          d.locations << "The Arctic - Jan Mayen"
        elsif d.title =~ /Norge|Norway/ui
          log.warn "[+] NO"
          d.locations << "Norway"
        elsif d.title =~ /Canada/ui
          log.warn "[+] CA"
          d.locations << "Canada"
        elsif d.title =~ /Bouvetøya|Bouvet/ui
          log.warn "[+] Bouvetøya"
          d.locations << "Bouvetøya"
        elsif d.title =~ /Peter I Øy/ui
          log.warn "[+] Peter I Øy"
          d.locations << "Peter I Øy"
        elsif d.title =~ /Dronning Maud Land/ui and d.locations.none? {|l| l =~ /Dronning Maud Land/ui }
          log.warn "[+] Dronning Maud Land"
          d.locations << "Dronning Maud Land"
        elsif d.title =~ /Antarctic|antarktis/ui and d.title !~ /Antarctic fur seals/ui and d.locations.none? {|l| l =~ /Antarctic/ui }
          log.warn "[+] Antarctica"
          d.locations << "The Antarctic"
        elsif d.title =~ /arktis|Arctic/ui and d.title !~ /sub-Arctic|antar[ck]ti[cs]/ui and d.locations.none? {|l| l =~ /Arctic/ }
          log.warn "[+] Arctic"
          d.locations << "The Arctic"
        end
        d.locations = location_fixer(d.locations)
        log.info d.locations.to_json
        log.info "="*80
      end
      
      if d.locations.nil?
        d.locations = []
      end
      
      

      d
    }
  end

  protected
  
  
  # Location object (http://api.npolar.no/schema/publication) for old string locations
  # Examples:
  #   [{"area":"Svalbard","country":"NO","placename":"Spitsbergen","hemisphere":"N"}]
  #   [{"area":"Arctic Ocean","country":"XZ","hemisphere":"N"},{"area":"Southern Ocean","country":"XZ","hemisphere":"S"}]
  #   [{"area":"Svalbard","country":"NO","placename":"Bjørnøya","hemisphere":"N"}]
  # 
  # The Arctic (1282)
  # Elsewhere/not applicable (939)  
  # The Arctic - Svalbard (584)
  # The Arctic - Svalbard - Spitsbergen (488)
  # The Arctic - Arctic Ocean (302)
  # The Antarctic (167)
  # The Arctic - other areas (97)
  # The Antarctic - Dronning Maud Land (81)
  # Russia (61)
  # The Arctic - Northern Barents Sea (58)
  # The Antarctic - Southern Ocean (59)
  # The Antarctic - other areas (46)
  # The Arctic - Eastern Barents Sea (43)
  # The Arctic - Fram Strait (35)
  # The Arctic - Bjørnøya (17)
  # The Arctic - Svalbard - Nordaustlandet (15)
  # The Arctic - Jan Mayen (8)
  # The Arctic - Svalbard - Hopen (3)
  # The Arctic - Svalbard - Barentsøya (2)
  # The Arctic - Svalbard - other islands (2)
  def location_fixer(locations)
    fixed = []

    fixed += locations.select {|l| l=~ /Svalbard/ui }.map {|l|
      placename = l.split("-").last.strip   
      { area: "Svalbard", country: "NO", placename: placename, hemisphere: "N"  }
    }
    
    fixed += locations.select {|l| l=~ /Bjørnøya/ui }.map {|l|
      placename = l.split("-").last.strip
      # Bjørnøya: http://placenames.npolar.no/stadnamn/Bj%C3%B8rn%C3%B8ya?ident=1221 74.38743 18.978537
      { area: "Svalbard", country: "NO", placename: placename,  hemisphere: "N"  }
    }
    
    fixed += locations.select {|l| l=~ /Jan Mayen/ui }.map {|l|
      placename = l.split("-").last.strip
      # Jan Mayen: http://placenames.npolar.no/stadnamn/Jan+Mayen?ident=18491 70.98455 -8.477247
      { area: "Jan Mayen", country: "NO", placename: placename , hemisphere: "N" }
    }
        
    fixed += locations.select {|l| l=~ /Arctic Ocean/ui }.map {|l|
      { area: "Arctic Ocean", country: "XZ",  hemisphere: "N"  }
    }
    
    fixed += locations.select {|l| l=~ /Bouvetøya/ui }.map {|l|
      { area: "Bouvetøya", country: "NO", hemisphere: "S" }
    }
    
    fixed += locations.select {|l| l=~ /Barents Sea/ui }.map {|l|
      { area: "Arctic Ocean", placename: "Barents Sea",  hemisphere: "N"  }
    }
    
    fixed += locations.select {|l| l=~ /Fram Strait/ui }.map {|l|
      { area: "Arctic Ocean", placename: "Fram Strait",  hemisphere: "N"  }
    }
    
    fixed += locations.select {|l| l=~ /Southern Ocean/ui }.map {|l|
      { area: "Southern Ocean", country: "XZ", hemisphere: "S" }
    }
    
    fixed += locations.select {|l| l=~ /Russia/ui }.map {|l|
      { country: "RU", hemisphere: "N" }
    }
    
    fixed += locations.select {|l| l=~ /Dronning Maud Land/ui }.map {|l|
      placename = l.split("-").last.strip
      { area: "Dronning Maud Land", country: "AQ", placename: placename, hemisphere: "S" }
    }
    
    if locations.any? {|l| l=~ /Norway/ui } and fixed.none? {|f| f[:country] == "NO"}
      fixed << { country: "NO", hemisphere: "N" }
    end
    if locations.any? {|l| l=~ /Canada/ui }
      fixed << { country: "CA", hemisphere: "N" }
    end
    if locations.any? {|l| l=~ /Arctic/ui and l !~ /Antarctic/ui } and fixed.none? {|f| f[:hemisphere] == "N"}
      fixed << { area: "Arctic", hemisphere: "N" }
    end
    if locations.any? {|l| l=~ /Antarctic/ui and l !~ /\sArctic/ui } and fixed.none? {|f| f[:hemisphere] == "S"}
      fixed << { area: "Antarctica", hemisphere: "S", country: "AQ" }
    end
    if locations.any? {|l| l=~ /elsewhere/ui }
      fixed << { area: "Other" }
    end
    
    fixed.uniq
    
  end
  
end
