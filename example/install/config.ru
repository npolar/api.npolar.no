# encoding: utf-8
# Configuration for http://api.npolar.no

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
require "./load"

log = Npolar::Api.log
Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"]
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"]

# Middleware for *all* requests - use with caution
# a. Security
use Rack::Throttle::Hourly,   :max => 1200000 # requests
use Rack::Throttle::Interval, :min => 0.00166666666 # 1/600 seconds
# use Npolar::Rack::SecureEdits (force TLS/SSL ie. https)

# b. Features
use Rack::JSONP
use Rack::Static, :urls => ["/css", "/img", "/xsl", "schema", "/favicon.ico", "/robots.txt"], :root => "public"

#use Rack::Recursive !?
#use Npolar::Rack::GeoJSON

# use Npolar::Rack::Editlog, Npolar::Storage::Solr.new("/api/editlog"), except => ["/path"]
# use Npolar::Rack::Editlog, Npolar::Storage::Couch.new("/api/editlog"), except => ["/path"]

# Bootstrap /service /user
service_seed = File.read()
# Autorun APIs
#database = "api_42" # is inside seed!
#client = Npolar::Api::Client.new(Npolar::Storage::Couch.uri+"/#{database}")
## Get all databases
#
#apis.select {|api|
#  api.autorun and "http://data.npolar.no/schema/api" == api.schema
#  
#}.each do | api |
#
#  storage, database = api.storage[0], api.storage[1]
#  log.info "#{api.path} autorunning API with #{storage} database \"#{database}\""
#
#  map api.path do
#
#    storage = Npolar::Storage::Couch.new(database)
#
#    if api.model?
#      storage.model = Npolar::Api.factory(api.model)
#    end
#
#    if api.auth?
#      auth = api.auth
#
#      # Open data => GET, HEAD are excepted from Authorization 
#      except = api.open? ? lambda {|request| ["GET", "HEAD"].include? request.request_method } : false
#      auth_methods = api.open? ? ["POST", "PUT", "DELETE"] : api.methods
#
#      authorizer = Npolar::Auth::Factory.instance("Couch", "api_user")
#
#      log.info "#{api.path} authorize #{auth_methods.join(", ")} for #{auth.authorize} in system #{auth.system} using #{auth.class.name}"
#
#      use Npolar::Rack::Authorizer, { :auth => auth,
#        :system => auth.system,
#        :except? => except
#      }
#    end
#
#    if api.search?
#  
#      if "Solr" == api.search[0]
#
#        use Views::Api::Index
#
#        use Npolar::Rack::Solrizer, { :core => "api",
#          :fq => ["workspace:biology", "collection:sighting"],
#          :facets => ["phylum", "class", "genus", "art", "species", "year", "month", "day", "category", "countryCode"],
#          :to_solr => Biology::Sighting.to_solr
#        }
#      elsif "Elastic" == api.search[0]
#      end
#
#    end
#
#
#    if api.accepts.key? "application/json"
#      before = Npolar::Api::Json.before_lambda
#      #after = Npolar::Api::Json.before_lambda
#    else
#      before = after = nil
#    end
#
#    run Npolar::Api::Core.new(nil,
#      :storage => storage,
#      :formats => api.formats.keys,
#      :methods => api.verbs,
#      :accepts => api.accepts.keys,
#      :before => before
#      # after
#    )
#  end
#end

map "/xapi" do
  storage = Npolar::Storage::Couch.new("api")
  storage.model = Api.new

  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "api",
    :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin"),
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method }
  }

  run Npolar::Api::Core.new(nil, { :storage => storage,
    :formats=>["json", "html"],
    :before => Npolar::Api::Json.before_lambda
  })

end

map "/user" do
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "api",
    :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin") }
    run Npolar::Api::Core.new(nil, {:storage => Npolar::Storage::Couch.new("api_user"), :methods => ["GET", "HEAD", "POST", "PUT"]}) # No DELETE
end

# 
# Please keep all map statements below in alphabetical order


map "/" do

  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"),
    :system => "api", :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin"),
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method }
  }

  use Views::Api::Index

  run Npolar::Rack::Solrizer.new(nil, {
    :core => "api",
    :facets => Npolar::Api.facets
   #@todo Convert from Atom-like JSON => Solr JSON
  })

  #map "/parameter" do
#unit
  #end

end


map "/atom" do
  # svc
  run Rack::Static.new(nil, {:urls => ["/description.xml"], :root => "views/opensearch"})
end

map "/biology" do

  run Npolar::Api::Core.new(Views::Biology::Index.new, :storage => nil, :methods =>  ["GET", "HEAD"])
    solrizer = Npolar::Rack::Solrizer.new(nil, {:core => "http://olav.npolar.no:8080/solr/marine_database",
    :facets => ["collection", "station_ss", "year_ss", "animalgroup_ss", "oograms_sms", "species_sms", "species_groups_sms", "sample_types_sms", "long_fs", "lat_fs"]})
    run Views::Api::Index.new(solrizer)

  map "/marine" do
    #run Views::Api::Index.new(solrizer)
  end

  map "/sighting" do
  
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    
    use Views::Api::Index

    use Npolar::Rack::Solrizer, { :core => "api",
      :fq => ["workspace:biology", "collection:sighting"],
      :facets => ["phylum", "class", "genus", "art", "species", "year", "month", "day", "category", "countryCode"],
      :to_solr => Biology::Sighting.to_solr
    }
    run Npolar::Api::Core.new(nil, :storage =>Npolar::Storage::Couch.new("biology_sighting"))

  end

end

# category
# /topics
# 


# /dataset
#   Discovery level metadata about a data product
#
# $ curl -inX POST https://api.npolar.no/dataset -d@/path/dataset.json -H "Content-Type: application/json"
map "/dataset" do

  Metadata::Dataset.formats = ["json", "atom", "dif", "iso", "xml"]
  Metadata::Dataset.accepts = ["application/json", "application/xml"]
  model = Metadata::Dataset.new

  storage = Npolar::Storage::Couch.new("dataset")
  storage.model = model

  # Auth
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "metadata",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
  # DIF XML (<-)-> JSON
  use Metadata::Rack::DifJsonizer

  # HTML
  use Views::Api::Index

  # Solr search (GET)
  # Solr save (POST, PUT)
  # Solr delete (DELETE)
  use Npolar::Rack::Solrizer, { :core => "api",
    :facets => Metadata::Dataset.facets,
    :force => {"workspace" => "metadata", "collection" => "dataset"},
    :to_solr => lambda {|hash|
    
        model = Metadata::Dataset.new(hash)
        model.to_solr        
    }
  }



  run Npolar::Api::Core.new(nil,
    { :storage => storage,
      :formats => Metadata::Dataset.formats,
      :accepts => Metadata::Dataset.accepts
    }
  )

  # /dataset/oai
  #   OAI-PMH repository
  map "/oai" do
    provider = Metadata::OaiRepository.new
    run Npolar::Rack::OaiSkeleton.new(Views::Api::Index.new, :provider => provider)
  end


  
end
# Best practice new open data API
# 1. API-description document (schema)
# 2. JSON schema (in API desc?)
# 3. Model
# 4. Middleware
# 5. Authorization

map "/ecotox" do
  # Show ecotox index on anything that is not a search
  run Npolar::Rack::Solrizer.new(Views::Ecotox::Index.new, :core => "ecotox" )
 


end

map "/gcmd" do

  run Gcmd::Concept.new

  map "/concept" do

    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "api",
      :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin"),
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method }
    }
    use Views::Api::Index

    use Npolar::Rack::Solrizer, { :core => "gcmd",
      :facets => ["concept", "ancestors", "children", "workspace", "collection", "cardinality", "tree", "label"]
    }

    run Npolar::Api::Core.new(nil, :storage => Npolar::Storage::Couch.new("gcmd_concept"))
  end
end

# map /image # image archive
# gis/geodata

map "/map" do
  
  solrizer = Npolar::Rack::Solrizer.new(Views::Map::Index.new, :core => "http://olav.npolar.no:8080/solr/map_archive/",
    :facets => ["country_of_origin_id", "published_year", "owner", "visible_externally", "scale", "area_id", "map_type_id","tag"])
  run Views::Api::Index.new(solrizer)

  map "/archive" do
    run Views::Api::Index.new(solrizer)
  end
  
end




map "/monitoring" do

  solrizer = Npolar::Rack::Solrizer.new(nil,
        :core => "http://bjarne.npolar.no:8983/indicators",
        :fq=>"type:Indicator", :condition => Npolar::Rack::Solrizer.searcher,
        :facets => ["theme_exact", "location_exact", "language_code"])

  run Views::Api::Index.new(solrizer)
  # run Extracter, "facets", map {}
  [["/indicator", "Indicator"], ["/indicator/meta","Indicator description"]].each do | path, type |
    #, "Indikator","Indikatorbeskrivelse", "Tolkning", "Interpretation","Rapport"].
    map path do
      solrizer = Npolar::Rack::Solrizer.new(nil,
        :core => "http://bjarne.npolar.no:8983/indicators",
        :fq=>"type:#{type}", :condition => Npolar::Rack::Solrizer.searcher,
        :facets => ["theme_exact", "location_exact", "language_code"])

      run Views::Api::Index.new(solrizer)
        
    end
  end
end

# @todo decide collections ie. paths
map "/oceanography" do
  #map "/cruise"
  #map 
  # Show ocean index on anything that is not a search
  #run Npolar::Rack::Solrizer.new(Views::Ocean::Index.new, :core => "http://localhost:8983/solr/oceanography/", :select => "select")
#<!-- ods.data.npolar.no -->
#<field name="cruise" type="string" indexed="true" stored="true" />
#<field name="temperature" type="tfloat" indexed="true" stored="true" multiValued="true" />
#<field name="fluorescence" type="tfloat" indexed="true" stored="true" multiValued="true" />
#<field name="turbidity" type="tfloat" indexed="true" stored="true" multiValued="true" />
#<field name="density" type="tfloat" indexed="true" stored="true" multiValued="true" />
#<field name="nitrogen" type="tfloat" indexed="true" stored="true" multiValued="true" />
#<field name="oxygen" type="tfloat" indexed="true" stored="true" multiValued="true" />
#<field name="pressure" type="tfloat" indexed="true" stored="true" multiValued="true" />
#<field name="salinity" type="tfloat" indexed="true" stored="true" multiValued="true" />
#<field name="par" type="tfloat" indexed="true" stored="true" multiValued="true" />
#<field name="station" type="string" indexed="true" stored="true" />
#<field name="originalstation" type="string" indexed="true" stored="true" multiValued="true" />
#<field name="instrument" type="string" indexed="true" stored="true" multiValued="true" />
#<field name="instrument_type" type="string" indexed="true" stored="true" multiValued="true" />
#<field name="platform" type="string" indexed="true" stored="true" multiValued="true" />
#<field name="filename" type="string" indexed="true" stored="true" multiValued="true" />
#<field name="datetime" type="date" indexed="true" stored="true" multiValued="false"/>


    use Views::Api::Index
    use Npolar::Rack::Solrizer, { :core => "oceanography",
     #   :fq => ["workspace:#{Oceanography::Physical::WORKSPACE}", "collection:#{Oceanography::Physical::COLLECTION}"],
      :facets => ["project", "parameter", "set", "mooring", "size", "category", "cruise", "platform", "station", "originalstation", "instrument", "instrument_type", "serial_number", "year", "month", "day"],
        #:ranges => ["temperature", "salinity", "pressure", "created", "depth", "echodepth", "latitude", "longitude", "oxygen", "nitrogen", "fluorescence", "par", "density"],
        #:to_solr => Oceanography::Physical.to_solr_lambda
    }
    run Npolar::Api::Core.new(nil, :storage =>Npolar::Storage::Couch.new("oceanography_physical"))
  

end


# @todo fork?
map "/org" do
  solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://bjarne.npolar.no:8983/solr/",
    :fq => ["type:Institution"], :facets => ["region", "institution_short_name", "city", "state_or_province", "country"]})
  run Views::Api::Index.new(solrizer)
end




# /publication
#   Publication API
#
# $ curl -inX POST https://api.npolar.no/publication -d@/path/publication.json -H "Content-Type: application/json"

#map "/rapportserie" do
#  map "/105" do
#  solrizer = Npolar::Rack::Solrizer.new(nil, {
#    :core => "http://olav.npolar.no:8080/solr/geonames",
#    :select => "select",
#    :fq => ["workspace:arkiv", "collection:*"],
#    :facets => ["workspace", "collection", "category"]
#  })
#  run Views::Api::Index.new(solrizer)
#  end
#end


# http://brage.bibsys.no/npolar/simple-search?locale=no&query=&submit=%C2%A0S%C3%B8k%21
# http://brage.bibsys.no/npolar/feed-query/rss_2.0?query=author:*
# For en informasjonsstrøm som gir de nyeste innførslene for selvvalgt søkeindeks og søketerm bruker du denne syntaksen:
# http://brage.bibsys.no/[institusjon]/feed-query/rss_2.0?query=[indeks]:[term] 
# hvor [institusjon] erstattes av den forkortelsen som er brukt i publiseringsarkivets internettadresse, [indeks] erstattes av søkeindeks og [term] erstattes av søkebegrep. Du kan bruke en av følgende indekser:
#  •	author
#  •	title
#  •	keyword
#  •	language
#  •	type





# @todo fork and merge with LDAP users, create pipeline
map "/person" do
  solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://bjarne.npolar.no:8983/solr/",
    :fq => ["type:Person"], :facets => ["region", "institution_short_name"]})
  run Views::Api::Index.new(solrizer)
end

#
#map "/project" do
#  solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://bjarne.npolar.no:8983/solr/",
#    :fq => ["type:Project"], :facets => ["region", "location_exact", "institution_short_name", "status"]})
#  run Views::Api::Index.new(solrizer)
#end

# 
map "/placename" do
  use Views::Api::Index

  #use Npolar::Rack::Solrizer, {
  #  :select => "select",
  #  :core => "http://localhost:8983/solr/api",
  #  :core => "http://olav.npolar.no:8080/solr/geonames",
  #
  #   New core (not-yet ready):
  #  :core => "http://dbmaster.data.npolar.no:8983/solr/placename",
  #  :fq => ["workspace:geo", "collection:geoname"],
  #  :summary => lambda {|doc| doc["definition"] },
  #  :facets => ["location", "hemisphere", "approved", "terrain", "country", "map", "reference", "north", "east"]
  #}

  run Npolar::Api::Core.new(nil, :storage => Npolar::Storage::Couch.new("placename"))

end






  # /schema
  # @todo Setup storage with revisions
  #map "/schema" do
  #  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"),
  #    :system => "api", :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin"),
  #    :except? => lambda {|request| ["GET", "HEAD"].include? request.requeschemst_method }
  #  }
  #  run Npolar::Api::Core.new(nil, {:storage => Npolar::Storage::Couch.new("schema"), :formats => ["html", "json"]})
  #end

map "/seaice" do
  # Show seaice index on anything that is not a search
  run Npolar::Rack::Solrizer.new(Views::Seaice::Index.new, :core => "/")

  #Seaice.collections.each do |scheme|
  #  map "/#{scheme}" do
  #
  #    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "seaice",
  #      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  #
  #    run Npolar::Api::Core.new(nil, :storage => Npolar::Storage::Couch.new("seaice"))
  #  
  #  end
  #end
end

map "/tracking" do
  # Show tracking index on anything that is not a search
  run Npolar::Rack::Solrizer.new(Views::Tracking::Index.new, :core => "")
  map "/iridium" do
    iridium = Tracking::Iridium.new
    run Npolar::Rack::Solrizer.new(Views::Collection.new(iridium), :core => "")
  end
end

map "/user" do
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "api",
    :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin") }
    run Npolar::Api::Core.new(nil, {:storage => Npolar::Storage::Couch.new("api_user"), :methods => ["GET", "HEAD", "POST", "PUT"]}) # No DELETE
end

