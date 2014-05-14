# encoding: utf-8
require "uri"

module Metadata

  # GCMD [DIF Hash](https://github.com/npolar/gcmd/blob/master/lib/gcmd/dif.rb) from [Npolar API dataset](http://api.npolar.no/schema/dataset)
  #
  # The mapping is defined in #to_hash. Each DIF element is typically
  # defined in a method named after the element (lowercased), like #dif_revision_history
  # 
  # Usage
  #   dif_hash = Metadata::DifHashifier.new(npolar_dataset_hash).to_hash
  #   dif_xml = Gcmd::Dif.new(dif_hash).to_xml
  #
  # GCMD DIF elements
  # A dataset may hold a special "gcmd" block containing raw DIF elements in
  # the following keys => DIF element mapping:
  # { "sciencekeywords" => dif.Parameters||[],
  #   "instruments" => dif.Sensor_Name||[],
  #   "platforms" => dif.Source_Name||[],
  #   "locations" => dif.Location||[],
  #   "projects" => dif.Project||[],
  #   "resolutions" => dif.Data_Resolution||[],
  #   "disciplines" => dif.Discipline||[],
  #   "idn_nodes" => dif.IDN_Node||[],
  #   "paleo_temporal_coverage" => dif.Paleo_Temporal_Coverage||[],
  #   "instruments" => dif.Sensor_Name||[],
  #   "references" => dif.Reference||[],
  #   "extended" => dif.Additional_Metadata||[],
  #   "citation" => dif.Data_Set_Citation||[]
  #   "entry_id" => dif.Entry_ID
  # }
  # Notice: GCMD-specific metadata (like IDN_Node, Parameters, and Location) is
  # also created automagically when there is an appropriate mapping.
  #
  # Links
  # * Metadata::Dataset#to_dif_hash 
  # * https://github.com/npolar/gcmd/blob/master/lib/gcmd/dif.rb
  # * http://gcmd.nasa.gov/add/difguide/
  #
  # Open issues
  # * "author" and set pI to author by default? (allowing for other authors?) organisations as authors
  # * Validating gcmd block (need concept version - where to store)
  # * GCMD concepts uuid
  #   # @todo map isotopics to topics
  # FIXME Dif author missing
  # FIXME OOps#<Role>author</Role>

  class DifHashifier < Hashie::Mash
    
    # Map [topics](http://api.npolar.no/schema/npolar_topic)to DIF Parameters (Science Keywords)
    # DIF Parameters: http://api.npolar.no/gcmd/concept/?q=&filter-concept=sciencekeywords
    # The main trouble is that 3 levels (down to Topic) are required by DIF - impossible for just "biology"/"geology"/"atmosphere"
    # @param [String] topic
    # @return [Hashie::Mash]
    def self.dif_Parameter(topic)

      dif_Topic, dif_Term, dif_Variable_Level_1 = case topic

        # Terms for BIOSPHERE from: http://api.npolar.no/gcmd/concept/?q=&start=0&limit=10&sort=&fq=concept:sciencekeywords&fq=ancestors:EARTH+SCIENCE&fq=ancestors:Science+Keywords&fq=ancestors:BIOSPHERE&fq=cardinality:3
        # * TERRESTRIAL ECOSYSTEMS (Science Keywords > EARTH SCIENCE > BIOSPHERE) | concept 
        # * VEGETATION (Science Keywords > EARTH SCIENCE > BIOSPHERE) | concept 
        # * ECOLOGICAL DYNAMICS (Science Keywords > EARTH SCIENCE > BIOSPHERE) | concept 
        # * AQUATIC ECOSYSTEMS (Science Keywords > EARTH SCIENCE > BIOSPHERE) | concept
        when "biology"
          ["BIOSPHERE", "ECOLOGICAL DYNAMICS"]

        # ECOTOXICOLOGY (Science Keywords > EARTH SCIENCE > BIOSPHERE > ECOLOGICAL DYNAMICS)
        # http://api.npolar.no/gcmd/concept/?q=impacts&start=0&limit=10&sort=&fq=ancestors:HUMAN+DIMENSIONS&fq=ancestors:ENVIRONMENTAL+IMPACTS
        when "ecotoxicology"
          ["BIOSPHERE", "ECOLOGICAL DYNAMICS", "ECOTOXICOLOGY"]

        # http://www.npolar.no/en/about-us/organization/research/geology-and-geophysics.html
        when "geology"
          ["SOLID EARTH"]

        # GLACIERS (Science Keywords > EARTH SCIENCE > CRYOSPHERE > GLACIERS/ICE SHEETS) | concept 
        # GLACIERS (Science Keywords > EARTH SCIENCE > TERRESTRIAL HYDROSPHERE > GLACIERS/ICE SHEETS) | concept 
        when "glaciology"
          ["CRYOSPHERE", "GLACIERS/ICE SHEETS", "GLACIERS"]

        # Science Keywords > EARTH SCIENCE > ATMOSPHERE
        # Topics: http://api.npolar.no/gcmd/concept/?q=atmosphere&start=0&limit=10&sort=&fq=concept:sciencekeywords&fq=ancestors:Science+Keywords&fq=ancestors:EARTH+SCIENCE&fq=ancestors:ATMOSPHERE&fq=cardinality:3
        when "atmosphere"
          ["ATMOSPHERE"]

        # Science Keywords > EARTH SCIENCE > LAND SURFACE > TOPOGRAPHY
        when "maps", "topography"
          ["LAND SURFACE", "TOPOGRAPHY"]

        # Science Keywords > EARTH SCIENCE > OCEANS > SEA ICE
        when "seaice"
          ["OCEANS", "SEA ICE"]

        when "oceanography"
          ["OCEANS", "SALINITY/DENSITY"]
          # Others/more:
          # WATER TEMPERATURE (Science Keywords > EARTH SCIENCE > OCEANS > OCEAN TEMPERATURE)
          # WATER PRESSURE (Science Keywords > EARTH SCIENCE > OCEANS > OCEAN PRESSURE)
          # DENSITY (Science Keywords > EARTH SCIENCE > OCEANS > SALINITY/DENSITY) | concept 
          # SALINITY (Science Keywords > EARTH SCIENCE > OCEANS > SALINITY/DENSITY) | concept 

        else
          []
      end

      Hashie::Mash.new({ "Category" => "EARTH SCIENCE",
        "Topic" => dif_Topic,
        "Term" => dif_Term,
        "Variable_Level_1" => dif_Variable_Level_1})
    end

    # @return [String]
    def access_constraints
      restrictions
    end

    # @return [Hashie::Mash] with GCMD DIF element names as keys
    def to_hash
      
        unless gcmd?
          self[:gcmd]=Hashie::Mash.new
        end
        unless coverage?
          self[:coverage]=[]
        end
        unless activity?
          self[:activity]=[]
        end
        unless changes?
          self[:changes]=[]
        end
        unless topics?
          self[:topics]=[]
        end
        unless licences?
          self[:licences]=[]
        end
        unless rights?
          self[:rights]=nil
        end
        # Code below is for a future Gcmd::DifSchema class
        # hash = {}
        # Gcmd::DifSchema.new.info.keys.each do |element|
        #   hash[element.to_sym]=self.send(element.downcase.to_sym)
        # end

        hash = Hashie::Mash.new({ "Entry_ID" => id||_id,
          "Entry_Title" => title,
          "Data_Set_Citation" => data_set_citation,
          "Personnel" => personnel,
          "Discipline" => discipline,
          "Parameters" => parameters,
          "ISO_Topic_Category" => iso_topic_category,
          "Keyword" => keyword,
          "Sensor_Name" => sensor_name,
          "Source_Name" => source_name,
          "Temporal_Coverage" => temporal_coverage,
          "Paleo_Temporal_Coverage" => paleo_temporal_coverage,
          "Data_Set_Progress" => data_set_progress,
          "Spatial_Coverage" => spatial_coverage,
          "Location" => location,
          "Data_Resolution" => data_resolution,
          "Project" => project,
          "Quality" => quality,
          "Access_Constraints" => access_constraints,
          "Use_Constraints" => rights||""+"\nLicences: "+(licences||[]).join(" or ")+"\n",
          "Data_Set_Language" => data_set_language,
          "Originating_Center" => originating_center,
          "Data_Center" => data_center,
          "Distribution" => distribution,
          "Multimedia_Sample" => multimedia_sample,
          "Reference" => reference,
          "Summary" => {"Abstract" => summary},
          "Related_URL" => related_url,
          "Parent_DIF" => parent_dif,
          "IDN_Node" => idn_node,
          

          # Watch out, all of these have multiplicity 1  
          #<xs:element ref="Originating_Metadata_Node" minOccurs="0" maxOccurs="1"/>
          #<xs:element ref="Metadata_Name" minOccurs="1" maxOccurs="1"/>
          #<xs:element ref="Metadata_Version" minOccurs="1" maxOccurs="1"/>
          #<xs:element ref="DIF_Creation_Date" minOccurs="0" maxOccurs="1"/>
          #<xs:element ref="Last_DIF_Revision_Date" minOccurs="0" maxOccurs="1"/>
          #<xs:element ref="DIF_Revision_History" minOccurs="0" maxOccurs="1"/>
          #<xs:element ref="Future_DIF_Review_Date" minOccurs="0" maxOccurs="1"/>
          #<xs:element ref="Private" minOccurs="0" maxOccurs="1"/>
          
          "Originating_Metadata_Node" => originating_metadata_node,
          "Metadata_Name" => "CEOS IDN DIF",
          "Metadata_Version" => ::Gcmd::Schema::VERSION,
          "DIF_Creation_Date" => (created||"T").split("T")[0],
          "Last_DIF_Revision_Date" => (updated||"T").split("T")[0],
          "DIF_Revision_History" => dif_revision_history,
          "Future_DIF_Review_Date" => future_dif_review_date,
          "Private" => draft == "yes" ? "True" : "False",
          "Extended_Metadata" => extended_metadata  
      })
      # Gcmd::Dif currently needs a ordered Hash to write valid DIF XML.
      # Therefore we insert all DIF elements above, and then remove empty ones
      # here to keep the ordering
      hash.each do |k,v|
        if v.respond_to?(:none?) and ( v.none? or v.nil? )
          hash.delete k
        end
      end
      hash

    end

    # In DIF, a data center is the organization or institution responsible for distributing the data
    # Organisation with roles "owner","resourceProvider", "publisher" are mapped to data centres
    def data_center
      (organisations||[]).select {|o|
        o.roles.include?("owner") or o.roles.include?("resourceProvider") or o.roles.include?("publisher")
        }.map {|o|

          resourceProviders = owners = publishers = []
          if o.links? and o.links.any?
            resourceProviders = (o.links||[]).select {|link| link.rel == "resourceProvider" }
            owners = (o.links||[]).select {|link| link.rel == "owner"}
            publishers = (o.links||[]).select {|link| link.rel == "publisher" }
          end
          
          if resourceProviders.any? and resourceProviders[0].href?
            data_center_url = resourceProviders[0].href
          elsif publishers.any? and publishers[0].href?
            data_center_url = publishers[0].href
          elsif owners.any? and owners[0].href?
            data_center_url = owners[0].href
          end
          
          data_center_contacts = personnel(/pointOfContact/, o.id)
          
          # Data Center Contact is required
          if data_center_contacts.none?
           data_center_contacts = [Hashie::Mash.new({
            "Role" => "Data Center Contact",
            "First_Name" => "",
            "Last_Name" => "",
            "Email" => [""]
          })]
          end
          
          if data_center_url =~ /npolar.no/ or o.id == "npolar.no"
            data_set_id = id
            if o.roles.include? "pointOfContact"
              data_center_contacts << { Role: "Data Center Contact",
                Last_Name: "Norwegian Polar Data",
                Email: "data[*]npolar.no" }
            end
          else
            data_set_id = nil
          end
          {
            "Data_Center_Name" => {
              "Short_Name" => o.gcmd_short_name||"MISSING-Short_Name",
              "Long_Name" => o.name
            },
            "Data_Center_URL" => data_center_url,
            "Data_Set_ID" => data_set_id,
            "Personnel" => data_center_contacts
          }
        } 
    end

    # Data_Set_Language = inferred from link[rel=data].hreflang
    # http://gcmd.gsfc.nasa.gov/add/difguide/data_set_language.html 
    def data_set_language
      links.select {|link| link.rel == "data"}.map {|link| link.hreflang }
    end

    # Data_Set_Progress
    def data_set_progress
      case progress
        when "complete", "", nil
          "Complete"
        when "ongoing"
          "In Work"
        when "planned"
          "Planned"
      end
    end

    # Note: Data_Resolution stems from "gcmd.resolution" array only
    def data_resolution
      gcmd.resolutions? ? gcmd.resolutions : []
    end

    def dif_revision_history
      history = []
     (changes||[]).sort_by {|edit| edit.datetime }.each {|edit|
      history << "#{(edit.datetime||"T").split("T")[0]}, #{edit.comment||"edited by"} #{edit.name} (#{edit.email})"
      }
      history.join("\n")
    end

    # Discipline (experimental)
    def discipline
      #gcmd.discipline? ? gcmd.discipline : []
      discipline_name = lambda {|topic|
        case topic
          when "biology", "geology", "oceanography", "geophysics"
            topic.upcase
          else ""
        end
      }

      # @mightdo Subdiscipline
      # @mightdo Detailed_Subdiscipline
      names = (topics||[]).map {|topic| discipline_name.call(topic) }.uniq
      if names.any?      
        { "Discipline_Name" => names[0] }
      else
        []
      end
    end

    # Distribution
    def distribution
      #gcmd.distribution? ? gcmd.distribution : []
      links.select {|link| link.rel =~ /data/ and link.href =~ /^http(s)?[:]/ }.map {|link|
        Hashie::Mash.new({
          Distribution_Media: "Online Internet (HTTP)", Distribution_Size: link[:length], Distribution_Format: link.type
        })
      }.uniq 
    end

    # Data_Set_Citation = "gcmd.citation" (if present) OR generated
    # using other metadata.
    #
    # http://gcmd.nasa.gov/add/difguide/data_set_citation.html
    def data_set_citation
      if gcmd.citation? and gcmd.citation.any?
        return gcmd.citation
      end
      
      dois = links.select {|link| link.rel == "doi"}
      publishers = (organisations||[]).select {|o| o.roles.include? "publisher" }
      html_links = links.select {|link| link.rel == "alternate" and link.type == "text/html"}
      
      doi = dois.any? ? dois[0].href : nil
      publisher = publishers.any? ? publishers[0].name : nil
      online_resource = html_links.any? ? html_links[0].href : nil

      # Release date if set, otherwise use published date if at least one data link
      released = released.nil? ? published : released
      release_date = (0 < links.select {|link| link.rel == "data"}.size) ? (released||"T").split("T")[0] : nil
      release_place = publisher =~ /^Norwegian Polar/ ? "Tromsø, Norway" : nil

      Hashie::Mash.new({ "Dataset_Creator" => authors.join(", "),
        "Dataset_Title" => title,
        "Dataset_Release_Date" => release_date,
        "Dataset_Release_Place" => release_place,
        "Dataset_Publisher" => publisher,
        "Dataset_DOI" =>  doi,
        "Online_Resource" => online_resource 
      })
    end

    # Entry_ID - not NOT from gcmd.entry_id
    def entry_id
      id||_id
    end
    
    def future_dif_review_date
      if released?
        now = DateTime.now
        rleased = DateTime.parse(released)
        if rleased > now
          rleased.to_date.to_s
        else
          nil
        end
      else
        nil
      end
    end
    # IDN_Node <= sets and owner
    def idn_node
      nodes = []

      norwegian = (owners||[]).select {|o| o.id =~ /\.no$/i }.size > 0
      norway = (placenames||[]).select{|c|c.country =~ /NO/i }.size > 0

      # AMD/NO
      if ((sets||[]).include?("antarctic") and norwegian)
        nodes << "AMD/NO"
      end

      #ARCTIC/NO
      if ((sets||[]).include?("arctic") and norway) 
        nodes << "ARCTIC/NO"
      end

      nodes += (sets||[]).map {|set|
        case set
          when /IPY/ui
            "IPY"
          when "arctic"
            "ARCTIC"
          when "antarctic"
            "AMD"
        end
      }.uniq
      nodes.select {|n| not n.nil? }.map { |n|
        {"Short_Name" => n }
      }
    end

    # Keyword
    def keyword
      ((tags||[])+(topics||[])).uniq
    end

    # Sensor_Name <= gcmd.instruments
    def instruments
      gcmd.instruments? ? gcmd.instruments : []
    end
    alias :sensor_name :instruments

    # Paleo_Temporal_Coverage
    def paleo_temporal_coverage
       gcmd.paleo_temporal_coverage? ? gcmd.paleo_temporal_coverage : []
    end

    # Parameters = gcmd.sciencekeywords + dif_Parameter(topic)
    def parameters
      parameters = gcmd.sciencekeywords? ? gcmd.sciencekeywords : []
      parameters += topics.map {|topic| self.class.dif_Parameter(topic) }
      parameters = parameters.uniq

      parameters.each_with_index do |p,i|
        if p.Topic.nil?
          # One of: http://api.npolar.no/gcmd/concept/?limit=250&q=&sort=&filter-concept=sciencekeywords&filter-cardinality=2&fields=title&format=csv
          p.Topic = "MISSING-TOPIC"
        end
        if p.Term.nil?
          # One of: http://api.npolar.no/gcmd/concept/?limit=250&q=&sort=&filter-concept=sciencekeywords&filter-cardinality=3&fields=title&format=csv
          p.Term = "MISSING-TERM"
        end
      end
      parameters

    end
    alias :sciencekeywords :parameters

    #http://gcmd.nasa.gov/add/difguide/extended_metadata.html
    def extended_metadata
      { "Metadata" => [
        {"Group" => "no.npolar.api", "Name" => "dataset.rev", "Value" => rev||_rev },
        { "Group" => "gov.nasa.gsfc.gcmd", "Name" => "metadata.keyword_version", "Value" => ::Gcmd::Concepts::VERSION }
      ]}
    end

    # ISO_Topic_Category = iso_topics
    def iso_topic_category
      (iso_topics||[]).map {|i|
        case i
          when "climatologyMeteorologyAtmosphere"
            "CLIMATOLOGY/METEOROLOGY/ATMOSPHERE"
          when "geoscientificInformation"
            "GEOSCIENTIFIC INFORMATION"
          else
            i.upcase   
        end
      }
    end
    
    def originating_center
      # or links[rel=datacenter]?
      (organisations||[]).select {|o| o.roles.include? "originator"}.map {|o| "#{o.name} (#{o.gcmd_short_name})" }.first
    end

    def originating_metadata_node
      (organisations||[]).select {|o| o.roles.include? "publisher"}.map {|o| "#{o.name} (#{o.gcmd_short_name})" }.first
    end

    # Location = placenames + gcmd.locations
    # The Norwegian polar areas are autmagically mapped to proper DIF Locations
    # Locations may also be stored in "gcmd.locations"
    def location
      location =  gcmd.locations? ? gcmd.locations  : []

      polar = {"Location_Category" => "GEOGRAPHIC REGION", "Location_Type" => "POLAR"}
      arctic = {"Location_Category" => "GEOGRAPHIC REGION", "Location_Type" => "ARCTIC"}

      (placenames||[]).each do | p |
        
        area = p.area
        if p.area? and p.area == ""
          area = p.placename
        end

        case area

          when /^(Svalbard|Jan Mayen)$/ then
            location << {
              "Location_Category" => "OCEAN",
              "Location_Type" => "ATLANTIC OCEAN",
              "Location_Subregion1" => "NORTH ATLANTIC OCEAN",
              "Location_Subregion2" => "SVALBARD AND JAN MAYEN",
              "Detailed_Location" => p.placename
            }
            location << polar
            location << arctic

          when /^(Dronning Maud Land|Antarctica|Antarktis)$/ then
            location << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "ANTARCTICA",
              "Detailed_Location" =>  p.placename
            }
            location << polar

          when /^(Bouvetøya|Bouvet Island)$/
            location << {
              "Location_Category" => "OCEAN",
              "Location_Type" => "ATLANTIC OCEAN",
              "Location_Subregion1" => "SOUTH ATLANTIC OCEAN",
              "Location_Subregion2" => "BOUVET ISLAND",
              "Detailed_Location" =>  p.placename
            }
            location << polar

          when "Peter I Øy" then
            locations << {
              "Location_Category" => "OCEAN",
              "Location_Type" => "PACIFIC OCEAN",
              "Location_Subregion1" => "SOUTH PACIFIC OCEAN",
              "Detailed_Location" => p.placename
            }
            locations << polar
            locations << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "ANTARCTICA",
              "Detailed_Location" => p.placename
            }
        end

      end
      location.uniq
    end

    # Multimedia_Sample
    def multimedia_sample
      #  multimedia_samples = gcmd.multimedia_samples? ? gcmd.multimedia_samples : [] @todo 
      links.select {|link| multimedia?(link) }.map {|link|
        Hashie::Mash.new({
          URL: link.href, Format: link.type, Caption: link.title
        })
      } 
    end

    def multimedia?(link)
      if link.type =~ /^(image|video|audio)\// or link.href =~ /[.](jp(e)?g|png|svg|tif(f)?)$/
        true
      else
        false
      end
    end


    def platforms
      gcmd.platforms? ? gcmd.platforms : []
    end
    alias :source_name :platforms

    # References = links[rel="reference"] + gcmd.references
    def references
      references = gcmd.references? ? gcmd.references : []
      references += links.select {|link| link.rel == "publication" }.map {|link|
        Hashie::Mash.new({
          Publication_Date: "Unknown", Title: link.title, Online_Resource: link.href,        
        })
      }
      
    end
    alias :reference :references

    # Related_URL = links (except internal, parent, and datacentre)
    def related_url

      typer = lambda {|type| case type
        when "dataset", "data"
          "GET DATA"
        when "metadata"
          "VIEW EXTENDED METADATA"
        when "project"
          "VIEW PROJECT HOME PAGE"
        when "edit", "service", "parent", "via"
          "GET SERVICE"
        # related DIF is hard/impossible to identify without a media type for DIF
        #  "GET RELATED METADATA RECORD (DIF)"
        when "internal", "parent", "datacentre" # parent => Parent_DIF, datacentre => Data_Center
          nil
        else # e.g. "related", "alternate", "", nil    
          "VIEW RELATED INFORMATION" 
        end

      }

      # GET SERVICE subtypes
      # http://api.npolar.no/gcmd/concept/?q=&limit=100&filter-concept=rucontenttype&filter-ancestors=GET+SERVICE&fields=title&format=csv

      # GET DATA subtypes
      # http://api.npolar.no/gcmd/concept/?q=&limit=100&filter-concept=rucontenttype&filter-ancestors=GET+DATA&fields=title&format=csv
      # Subtype for THREDDS
      #http://www.unidata.ucar.edu/software/thredds/current/tds/interfaceSpec/NetcdfSubsetService.html#REST
      # wms!
      subtyper = lambda {|link, dif_type="GET DATA"|
        if dif_type =~ /GET (DATA|SERVICE)/
          if link.type =~ /application\/(x-)?netcdf/
            "THREDDS DATA"
          elsif link.href =~ /\.(cdl|nc)$/i
            "THREDDS DATA"
          elsif link.href =~ /request=GetCapabilities&service=WMS/
            "GET WEB MAP SERVICE (WMS)"
          elsif link.type == "application/atom+xml"
            nil
          elsif link.type == "application/json"
            nil
          end
        end
      }

      related_url = []
      # All links except internal (hidden), datacentre (in Online_Resource) and
      # publication (in References)
      links.reject {|link| link.rel =~ /internal|datacentre|publication/ }.each {|link|

        dif_type = typer.call(link.rel)
        dif_subtype = subtyper.call(link)

        r = Hashie::Mash.new({ "URL_Content_Type" => {"Type" => dif_type},
          "URL" => link.href, "Description" => link.title||link.rel.capitalize })

        if (link.type? and not link.type.nil?)
          r.Description += " (#{link.type})"
        end
        if not dif_subtype.nil?
          r.URL_Content_Type.Subtype = dif_subtype
        end
    
        related_url << r
        
      }
      related_url
    end

    # Parent_DIF = links[rel=parent] (yes unbounded)
    def parent_dif
      links.select {|link| link.rel == "parent" }.map {|link| link.href.gsub(/json$/, "xml") }
    end

    # Personnel <= people
    def personnel(role_filter=/principalInvestigator|processor|author|editor/, organisation=nil)

      personnel = []
      (people||[]).select {|p| organisation.nil? ? true : organisation == p.organisation
      }.each do |p|

        dif_Role = p.roles.reject {|r| r !~ role_filter}.map {|role|
          case role
            when "principalInvestigator"
              "Investigator"
            when "processor"
              "Technical Contact"
            when "pointOfContact"
              "Data Center Contact"
            when "editor"
              "DIF Author"
            else nil
          end
        }

        if dif_Role.any?

          personnel << Hashie::Mash.new({
            "Role" => dif_Role,
            "First_Name" => p.first_name,
            "Last_Name" => p.last_name,
            "Email" => [p.email]
          })
        end
      end
      
      #if edits.any?
      #  # FIXME select max date
      #  dif_author = edits.last
      #else
      #  dif_author = Hashie::Mash.new({ first_name: updated_by, last_name: "", email: "" })
      #end
      
      #personnel << Hashie::Mash.new({
      #  "Role" => "DIF Author",
      #  "First_Name" => dif_author.first_name,
      #  "Last_Name" =>dif_author.last_name,
      #  "Email" => dif_author.email
      #})
      
      personnel
    end
  
    # Spatial_Coverage <= coverage
    def spatial_coverage
      coverage.map {|c|
        {
          "Southernmost_Latitude" => c.south,
          "Northernmost_Latitude" => c.north,
          "Westernmost_Longitude" => c.west,
          "Easternmost_Longitude" => c.east  
        }
      }        
    end

    # Temporal_Coverage <= activity
    def temporal_coverage
      activity.map {|a|
        {
          "Start_Date" => (a.start||"T").split("T")[0],
          "Stop_Date" => (a.stop||"T").split("T")[0] 
        }
      }        
    end

    # Use_Constraints <= rights
    def use_constraints
      rights
    end

    protected

    def authors
      if people.nil?
        return []
      end
      people.select {|p|
        p.roles.include? "principalInvestigator" or p.roles.include? "author"
      }.map {|a| a.first_name+" "+a.last_name }.uniq
    end

    def owners
      if organisations.nil?
        return []
      end
      organisations.select {|o|
        o.roles.include? "owner"
      }
    end

    def links
      if self[:links].nil?
        return []
      end
      self[:links]
    end


  end
end
