require "logger"

module Metadata

  # New "sets" - using domain names and lowercase
  # https://github.com/npolar/api.npolar.no/issues/20
  
  # Production
  # http://api.npolar.no/editlog/
  
  # $ ./bin/npolar-api-migrator /dataset ::Metadata::DatasetMigration6 --really=false > /dev/null
  class DatasetMigration6

    attr_accessor :log
    
    @@changes = JSON.parse(File.read "migration/dataset/changes.txt")

   
    def migrations
      #[unescape, changes_not_edits, empty_storage_comment, remove_restricted]
      [fix_changes]
    end
    
    # rights if attributed => publisher not always npolar.no
    # <Future_DIF_Review_Date>2009-05-22</Future_DIF_Review_Date> oops
    # also revisit dif hashifier for "changes"
# http://www.nodc.noaa.gov/General/NODC-Archive/seanamelist.txt
    def unescape
      lambda {|d|
        if d.to_json =~ /\&\#x[\dA-F][\dA-F]/
          
          d.each do |k,v|
            if v =~ /\&\#x[\dA-F][\dA-F]/ui
              
              
              if k == "schema"
                d[k] = CGI.unescapeHTML(v)
                log.info "#{d.id} #{k} #{d[k]}"
              elsif k == "rights" 
                if v =~ /Open data. Free to reuse if attributed to the Norwegian Polar Institute/
                  d[k] = "Open data: Free to reuse if attributed to the Norwegian Polar Institute"
                elsif /Protected/
                  d[k] = "Protected by Norwegian copyright law: http://lovdata.no/dokument/NL/lov/1961-05-12-2"
                  d.licences = ["http://lovdata.no/dokument/NL/lov/1961-05-12-2"]
                end
              else
                log.warn "#{d.id} #{k} #{d[k]}"
              end

            end
            
          end
        end
        

        d
      }
    end
    
     def changes_not_edits
      lambda {|d|
        if d.edits?
          
          users = d.edits.map {|e| e.email }.uniq
          
          d[:changes] = users.map {|email|
            
            edits = d.edits.select {|e| e.email == email}.sort_by {|e|e.edited}
            if edits.size == 1
              edits
            else
              [edits.first, edits.last]
            end 
          }.flatten.map {|c|
            c.datetime = c.edited
            c.delete :edited
            if c.datetime == d.created
              c.comment = "created"
            else
              c.comment = "edited"
            end
            
            c
          }.sort_by {|c|c.datetime}
          log.info d[:changes].to_json
          d.delete :edits
        end
        d
        }
     end
     
    def empty_storage_comment
      lambda {|d|
        if d.comment? and d.comment == "Storage:"
          d.delete :comment
        end
        d
        }
    end
    
    def remove_restricted
      lambda {|d|
        d.delete :restricted
        d
        }
    end
    
    def fix_changes
      lambda {|d|
        if idx = @@changes.index {|a| a.any? {|c| c.key? "id" and c["id"] == d.id } }
          d[:changes] = @@changes[idx].map {|c|
            { email: c["email"], name: c["name"], datetime: c["datetime"], comment: c["comment"] }
          }
        else
          d[:changes] = [{email: d.created_by, name: d.created_by, datetime: d.created, comment: "created"}]
          if d.updated != d.created
            d[:changes] << {email: d.updated_by, name: d.updated_by, datetime: d.updated, comment: "edited"}
          end
          log.error d.id+" "+d.title
          log.warn d.changes.to_json
        end
        
        
        if d[:changes].to_json !~ /#{d.created_by}/
          d[:created_by] =  d.changes.first.name
          log.info d.created_by
        end

        if d[:changes].none? {|c|c.comment =~ /created/}
          before = d.changes
          d[:changes] = [{email: d.created_by, name: d.created_by, datetime: d.created, comment: "created"}]
          d[:changes] += before
        end

        if not d.changes?
          d[:changes] = []
        end   
        
        
        d
        }
    end

  end
end


    #protected
    #
    # def check_dif_xml_valid
    #  lambda {|d|
    #    schema = ::Gcmd::Schema.new
    #    d = model.class.new(d)
    #    
    #    log.info d.title
    #    
    #    errors = schema.validate_xml( d.to_dif )
    #    
    #    if errors.any?
    #      log.warn errors.to_json
    #      d.errors = errors
    #    end
    #    d
    #  }
    #end
# Add npolar *org* when any people has mail npolar.no
# Ugh d is hashie mash not dataset no matter
     
    
    #org links from links and from people.email.spllit@1
    
    # rights if attributed => publisher not always npolar.no
    # <Future_DIF_Review_Date>2009-05-22</Future_DIF_Review_Date> oops
    # also revisit dif hashifier for "changes"



#W, [2014-05-12T16:44:24.323344 #16376]  WARN -- : 0cd3e54a-3f15-44a4-ba01-9ed39624c59b quality Scale Range: Maximum (zoomed in)  1:5,000; Minimum (zoomed out)  1:150,000,000
#Spatial Reference: WGS84&#x2F;UTM zone 33N (EPSG: 32633)
#W, [2014-05-12T16:44:24.323435 #16376]  W, [2014-05-12T16:44:24.547305 #16376]  WARN -- : 3682182c-3ec5-5170-ae12-4d14a714cec4 summary Complete, kinematic GPS profile along the route of the Norwegian-U.S. IPY traverse of East Antarctica, from Troll Station to &#x27;Camp Winter&#x27; at -86,8S, 54,4E, from the South Pole (-90, 0) back to Troll Station across the Recovery Lakes region, and static GPS measurements of snow stakes at selected locations along the route. Instruments: Trimble R7 and Trimble 5700 dual-frequency geodetic receivers with Zephyr Geodetic antennas set at 5 sec logging intervals, with Terrapos post-processing allowing high-level accuracy without base stations. The scientific objectives are to investigate surface topography and dynamics of the ice sheet, determine the spatial variability of the surface topography, validate remote sensing data, determine local topography around drill sites and to determine flow vectors at drill sites. Some of the stakes have been revisited, and some new stakes have been positioned.
#W, [2014-05-12T16:44:24.547379 #16376]  WARN -- : 3682182c-3ec5-5170-ae12-4d14a714cec4 comment Duplicate of https:&#x2F;&#x2F;api.npolar.no&#x2F;dataset&#x2F;bc460306-87e7-11e2-8c07-005056ad0004
#Action: DELETE
#WARN -- : 0cd3e54a-3f15-44a4-ba01-9ed39624c59b comment Ved endringer i lover&#x2F;forskrifter som regulerer skuterkjøring.
#W, [2014-05-12T16:44:24.413672 #16376]  WARN -- : 1e29fe0a-2eb8-48d1-8841-2415e53139be quality Scale Range: Maximum (zoomed in)  1:5,000 ; Minimum (zoomed out)  1:150,000,000
#Spatial Reference: WGS84&#x2F;UTM zone 33N (EPSG: 32633)
#W, [2014-05-12T16:44:24.413726 #16376]  WARN -- : 1e29fe0a-2eb8-48d1-8841-2415e53139be comment Datasett oppdatert ved endringer i lover&#x2F;forskrifter som regulerer skuterkjøring.
#W, [2014-05-12T16:44:24.935369 #16376]  WARN -- : 926d599e-38ea-546e-9e69-bfc731691d3c restrictions Attribution-Noncommercial-Share Alike 3.0 Unported, see url for more details.http:&#x2F;&#x2F;creativecommons.org&#x2F;licenses&#x2F;by-nc-sa&#x2F;3.0&#x2F;
#W, [2014-05-12T16:44:25.339542 #16376]  WARN -- : f1fc782a-fa7b-11e2-bd10-005056ad0004 summary On many glaciers in Svalbard, three surface types are visible on SAR images, the dark glacier ice at the glacier&#x27;s lower end, the brighter superimposed ice in the middle, and the white firn at the higher elevations. Surface classification of these types is valuable especially since the retreat or advance of the firn area provides information on the status of the glacier. While the snowline reacts immediately to annual changes, the firn area smoothes out these short-term changes and shows, similar to the glacier front, longer-term changes of the glaciers. 
##Glacier Firn Area Change is based on the &quot;Glacier Surface Type - Svalbard&quot; dataset, presenting the actual area value sper glacier and year as tabular data to be plotted graphically
#W, [2014-05-12T16:44:24.843308 #16376]  WARN -- : 7c5ee27d-b7fd-4309-af82-77754b0ba9a0 quality Scale Range: Maximum (zoomed in)  1:5000; Minimum (zoomed out)  1:150000000
#Spatial Reference: WGS84&#x2F;UTM zone 33N (EPSG: 32633)

#,  [{"email":"Hans.wolkers@gmail.com","name":"Hans Wolkers","datetime":"2009-05-22T12:00:00Z","comment":"created"},{"name":"Ruben Dens","email":"ruben@npolar.no","datetime":"2014-03-06T08:50:55Z","comment":"edited" }