#encoding: utf-8

module Metadata

  # Converts a dataset to a proper input Hash(ie) for Gcmd::Dif
  # * Metadata::Dataset#to_dif_hash 
  # * https://github.com/npolar/gcmd/blob/master/lib/gcmd/dif.rb
  class DifHashifier < Hashie::Mash

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
        unless edits?
          self[:edits]=[]
        end

        hash = Hashie::Mash.new({ "Entry_ID" => id||_id,
          "Entry_Title" => title,
          "Data_Set_Citation" => data_set_citation,
          "Personnel" => personnel,
          "Discipline" => discipline,
          "Parameters" => gcmd.sciencekeywords,
          "ISO_Topic_Category" => iso_topic_categInvestigatorory,
          "Keyword" => tags,
          "Sensor_Name" => nil,
          "Source_Name" => nil,
          "Temporal_Coverage" => temporal_coverage,
          "Paleo_Temporal_Coverage" => [],
          "Data_Set_Progress" => data_set_progress,
          "Spatial_Coverage" => spatial_coverage,
          "Location" => location,
          "Data_Resolution" => data_resolution,
          "Project" => gcmd.projects,
          "Quality" => quality,
          "Access_Constraints" => nil,
          "Use_Constraints" => ""+(licences||[]).join(" or "), #rights, #+licences?
          "Data_Set_Language" => nil,
          "Originating_Center" => nil,
          "Data_Center" => data_center,
          "Summary" => {"Abstract" => summary},
          "Related_URL" => related_url,
          "Parent_DIF" => parent_dif,
          #Distribution
          #Multimedia_Sample
          #Reference
          #IDN_Node
          "Originating_Metadata_Node" => nil,
          "Metadata_Name" => "CEOS IDN DIF",
          "Metadata_Version" => ::Gcmd::Schema::VERSION,
          "Data_Center" => data_center,
          "DIF_Creation_Date" => (published||"T").split("T")[0],
          "Last_DIF_Revision_Date" => (updated||"T").split("T")[0],
          "DIF_Revision_History" => (edits||[]).join("\n"),
          "Future_DIF_Review_Date" => nil,
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

    # Data_Center, defined as organization with at least one of the following
    # roles "owner", "resourceProvider", "publisher"
    def data_center
      (organisations||[]).select {|o|
        o.roles.include?("owner") or o.roles.include?("publisher") or o.roles.include?("resourceProvider") }.map {|o|
        {
          "Data_Center_Name" => {
            "Short_Name" => o.gcmd_short_name,
            "Long_Name" => o.name
          },
          "Data_Center_URL" => o[:uri],
          "Data_Set_ID" => id,
          "Personnel" => personnel(/pointOfContact/)
        }
      } 
    end

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

    def discipline
      discipline_name = lambda {|topic|
        case topic
          when "biology"
            "BIOLOGY"
          else ""
        end
      }

      names = topics.map {|topic| discipline_name.call(topic) }.uniq
      if names.any?      
        { "Discipline_Name" => names[0] }
      else
        []
      end
    end
  
    def data_set_citation
      dois = links.select {|link| link.rel == "doi"}
      publishers = (organisations||[]).select {|o| o.roles.include? "publisher" }
      html_links = links.select {|link| link.rel == "alternate" and link.type == "text/html"}

      doi = dois.any? ? dois[0].href : nil
      publisher = publishers.any? ? publishers[0].name : ""
      online_resource = html_links.any? ? html_links[0].href : ""
      
      { "Dataset_Creator" => authors.join(", "),
        "Dataset_Title" => title,
        "Dataset_Release_Date" => (published||"T").split("T")[0],
        "Dataset_Publisher" => publisher,
        "Dataset_DOI" =>  doi,
        "Online_Resource" => online_resource 
      }
    end

    def idn_node
#      <IDN_Node>
#<Short_Name>ARCTIC/NO</Short_Name>
#</IDN_Node>
#<IDN_Node>
#<Short_Name>ARCTIC</Short_Name>
#</IDN_Node>
    end
  
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

    def authors
      if people.nil?
        return []
      end
      people.select {|p|
          p.roles.include? "principalInvestigator"
      }.map {|a| a.first_name+" "+a.last_name }
    end

    def links
      if self[:links].nil?
        return []
      end
      self[:links]
    end

    def location
      location = []

      # What is the primary trigger for these?
      polar = {"Location_Category" => "GEOGRAPHIC REGION", "Location_Type" => "POLAR"}
      arctic = {"Location_Category" => "GEOGRAPHIC REGION", "Location_Type" => "ARCTIC"}

      (placenames||[]).each do | p |
                  
        case p.area
          when /^(Svalbard|Jan Mayen)$/ then
            location << {
              "Location_Category" => "OCEAN",
              "Location_Type" => "ATLANTIC OCEAN",
              "Location_Subregion1" => "NORTH ATLANTIC OCEAN",
              "Location_Subregion2" => "SVALBARD AND JAN MAYEN",
              "Detailed_Location" => p.placename
            }
            location << polar_region
            location << arctic
          when /^Dronning Maud Land|Antarktica$/ then
            location << {
              "Location_Category" => "CONTINENT",
              "Location_Type" => "ANTARCTICA",
              "Detailed_Location" =>  p.placename
            }
            location << polar_region
        end
      end
        location.uniq       
    end

    def related_url
      typer = lambda {|type| case type
        when "dataset", "data"
          "GET DATA"
        when "metadata"
          "VIEW EXTENDED METADATA"
        when "project"
          "VIEW PROJECT HOME PAGE"
        when "service"
          "GET SERVICE"
        when "parent"
          "GET RELATED METADATA RECORD (DIF)"
        when "edit", "alternate"
          nil
        when "related"    
          "VIEW RELATED INFORMATION" 
        else
          nil
        end
      }

      related_url = []
      links.each {|link|

        dif_type = typer.call(link.rel)

        if "parent" == link.rel
          link.href = link.href.gsub(/json$/, "xml")
        end

        unless dif_type.nil?
          related_url << { "URL_Content_Type" => {"Type" => dif_type }, "URL" => link.href,
          "Description" => link.title }
        end
      }
      related_url
    end

    def parent_dif
      []
    end

    def personnel(role_filter=/principalInvestigator|processor|editor/)

      personnel = []
      (people||[]).each do |p|

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
            else role
          end
        }

        if dif_Role.any?
          personnel << {
            "Role" => dif_Role,
            "First_Name" => p.first_name,
            "Last_Name" => p.last_name,
            "Email" => [p.email]
          } 
        end
        

        
      end
      personnel
    end
  
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

    def temporal_coverage
      activity.map {|a|
        {
          "Start_Date" => (a.start||"T").split("T")[0],
          "Stop_Date" => (a.stop||"T").split("T")[0] 
        }
      }        
    end





  end
end
