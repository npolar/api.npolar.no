# encoding: utf-8
# $ ./bin/npolar-api-migrator /biology/marine/sample/ MarineBiologySampleMigration1 --really=false > /dev/null

class MarineBiologySampleMigration1

  attr_accessor :log
  
  def model
    Marine::Samples.new
  end
 
  def migrations
    [split_programs, add_expedition]
  end
  
  def add_expedition
      lambda {|d|
        
      if not d.expedition?
        if d.sample_name =~ /^((MOSJ|ICE|ALK|CLE|FLT|MAR|MER|NON|OTI|SANA|ice96B|mø00)\d+(AB)?)[-_\s]/ui

          d.expedition = $1

        elsif d.sample_name =~ /^(ice95A|ice95b|ice96a|ice96B|mø99A|02 UNIS|03 UNIS|04BIO|mø99A|mø99B|mø00|UN04|AB320_04|05CAB|06MAR|06ABS|2004UV|2003UV|04CAB|MAR06|CLEO07|ALK10a).+/ui

          d.expedition = $1

        else

          log.warn d.sample_name

        end
      end
      d
    }
  end
  
  def split_programs
    lambda {|d|
      
      if d.programs =~ /.*[,;|].*/
        was = d.programs
        d.programs = d.programs.split(/[,;|]/).map {|p| p.strip}.uniq
        log.info "#{d.programs} <= #{was}"
      end
      d
    }
  end
end