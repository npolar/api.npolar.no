# encoding: utf-8
# This config.ru is the *production* configuration for api.npolar.no
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require "./load"

Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"]
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"]

Metadata::Dataset.formats = ["atom", "json", "dif", "iso", "xml"]
Metadata::Dataset.accepts = ["json", "dif", "xml"]


# Middleware for *all* requests - use with caution
# a. Security
# use Rack::Throttle::Hourly,   :max => 1200 # requests
# use Rack::Throttle::Interval, :min => 110.1 # seconds
# use Npolar::Rack::SecureEdits (force TLS/SSL ie. https)

# b. Features
use Rack::JSONP
use Rack::Static, :urls => ["/css", "/img", "/xsl", "/favicon.ico", "/robots.txt"], :root => "public"
# use Npolar::Rack::Editlog, Npolar::Storage::Solr.new("/api/editlog")

# http(s)://api.npolar.no/
# 
# Please keep all map statements below in alphabetical order
map "/" do 
  solrizer = Npolar::Rack::Solrizer.new(nil,
    :core => "",
    :facets => ["collection", "workspace", "methods", "parameter", "person", "org", "project", "draft", "link", "group", "set", "category", "country", "placename", "iso_3166-1", "iso_3166-2", "hemisphere", "source", "year", "month", "day", "editor", "referenceYear", "edited-y-m-d", "updated-y-m-d",  "license"]
  )
  search = Views::Api::Index.new(solrizer)

  use Npolar::Rack::Atomizer

  run search

  # The map sections below are for the internal "api" workspace
  map "/parameter" do
  end

  map "/schema" do
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"),
      :system => "api", :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin"),
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method }
    }
    run Npolar::Api::Core.new(nil, {:storage => Npolar::Storage::Couch.new("schema"), :formats => ["html", "json"]})
  end

  map "/user" do
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "api",
    :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin") }
    run Npolar::Api::Core.new(nil, {:storage => Npolar::Storage::Couch.new("api_user"), :methods => ["GET", "HEAD", "POST", "PUT"]}) # No DELETE
  end
end


map "/atom" do
  # svc
  run Rack::Static.new(nil, {:urls => ["/description.xml"], :root => "views/opensearch"})
end

map "/biology" do

  #run Npolar::Api::Core.new(Views::Biology::Index.new, :storage => nil, :methods =>  ["GET", "HEAD"])
    solrizer = Npolar::Rack::Solrizer.new(nil, {:core => "http://olav.npolar.no:8080/solr/marine_database",
    :facets => ["collection", "station_ss", "year_ss", "animalgroup_ss", "programs_sms", "species_sms", "species_groups_sms", "sample_types_sms", "long_fs", "lat_fs"]})
    run Views::Api::Index.new(solrizer)

  map "/marine" do
    run Views::Api::Index.new(solrizer)
  end

  map "/sighting" do
  
    index = Views::Collection.new
    index.id = "view_biology_observation_index"
    #index.storage = api
  
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "biology",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
    use Npolar::Rack::Solrizer, { :core => "", :fq => ["workspace:arkiv", "collection:*"]}
  
    run Npolar::Api::Core.new(index, :storage =>Npolar::Storage::Couch.new("biology_observation"))

  end

end

map "/ecotox" do
  # Show ecotox index on anything that is not a search
  run Npolar::Rack::Solrizer.new(Views::Ecotox::Index.new, :core => "ecotox" )
 
  #map compound
  map "/report" do
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "ecotox",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method }
    }
    #use Npolar::Rack::TikaExtracter
    run Npolar::Api::Core.new(nil, :storage => Npolar::Storage::Couch.new("ecotox"))

  end
end

map "/gcmd" do

  run Npolar::Api::Core.new(Gcmd::Concept.new, :storage => Npolar::Storage::Couch.new("gcmd_concept"))

  map "/concept" do

    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "api",
      :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin"),
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method }
    }
    use Views::Api::Index

    use Npolar::Rack::Solrizer, { :core => "http://solr:8983/solr/collection1",
      :facets => ["concept", "ancestors", "children", "workspace", "collection", "cardinality", "tree", "label", "id"]
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


map "/metadata" do

  solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://olav.npolar.no:8080/pmdb/",
    :fq => ["type:Data*"], :facets => ["region", "institution_long_name"]})

  #metadata_workspace_index = Views::Workspace.new(solrizer)
  #metadata_workspace_index.id = "view_metadata_index"
  #metadata_workspace_index.storage = api
  #run Npolar::Api::Core.new(metadata_workspace_index, :storage => nil, :methods =>  ["GET", "HEAD"])
  # run metadata_workspace_index #Views::Api::Index.new(solrizer)


  map "/oai" do
    run Npolar::Rack::OaiSkeleton.new(Views::Api::Index.new, :provider => Metadata::OaiRepository.new)
  end

  map "/dataset" do
    # Show metadata index on anything that is not a search
    index = Views::Metadata::Index.new
    index.id = "view_metadata_dataset_index"
    #index.storage = api

    model = Metadata::Dataset.new
    #model.schema = File.read(File.expand_path(File.join(".", "lib", "metadata/dataset-schema.json")))
    #p model.schema
    
    storage = Npolar::Storage::Couch.new("metadata_dataset")
    # storage.model = model

    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "metadata",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
    use Metadata::Rack::DifJsonizer

    use Npolar::Rack::Solrizer, { :core => "", :model => model }

    run Npolar::Api::Core.new(index,
      { :storage => storage,
        :formats => Metadata::Dataset.formats, #,
        :accepts => Metadata::Dataset.accepts
      }
    )
  end
end

map "/monitoring/" do

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

map "/oceanography" do

  #map "/cruise"
  #map 
  # Show ocean index on anything that is not a search
  run Npolar::Rack::Solrizer.new(Views::Ocean::Index.new, :core => "http://localhost:8983/solr", :select => "select")
end

map "/org" do
  solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://bjarne.npolar.no:8983/solr/",
    :fq => ["type:Institution"], :facets => ["region", "institution_short_name", "city", "state_or_province", "country"]})
  run Views::Api::Index.new(solrizer)
end

map "/person" do
  solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://bjarne.npolar.no:8983/solr/",
    :fq => ["type:Person"], :facets => ["region", "institution_short_name"]})
  run Views::Api::Index.new(solrizer)
end

map "/project" do
  solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://bjarne.npolar.no:8983/solr/",
    :fq => ["type:Project"], :facets => ["region", "location_exact", "institution_short_name", "status"]})
  run Views::Api::Index.new(solrizer)
end

map "/placename" do
  solrizer = Npolar::Rack::Solrizer.new(nil, {
    :select => "select",
    :core => "http://dbmaster.data.npolar.no:8983/solr/placename",
    :fq => ["workspace:geo", "collection:geoname"],
    :summary => lambda {|doc| doc["definition"] },
    :facets => ["location", "hemisphere", "approved", "terrain", "country", "map", "reference", "north", "east"]
  })
  run Views::Api::Index.new(solrizer)
end

map "/rapportserie" do
  map "/105" do
  solrizer = Npolar::Rack::Solrizer.new(nil, {
    :core => "http://olav.npolar.no:8080/solr/geonames",
    :select => "select",
    :fq => ["workspace:arkiv", "collection:*"],
    :facets => ["workspace", "collection", "category"]
  })
  run Views::Api::Index.new(solrizer)
  end
end

map "/polar-bear" do
  map "/reference" do
    solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://bjarne.npolar.no:8983/references",
      :facets => ["source", "popularity", "keyword", "year", "pages", "author_exact", "sku", "periodical", "timestamp"] })
    run Views::Api::Index.new(solrizer)
  end
end

# http://brage.bibsys.no/npolar/simple-search?locale=no&query=&submit=%C2%A0S%C3%B8k%21
#http://brage.bibsys.no/npolar/feed-query/rss_2.0?query=author:*
#For en informasjonsstrøm som gir de nyeste innførslene for selvvalgt søkeindeks og søketerm bruker du denne syntaksen:
#http://brage.bibsys.no/[institusjon]/feed-query/rss_2.0?query=[indeks]:[term] 
#hvor [institusjon] erstattes av den forkortelsen som er brukt i publiseringsarkivets internettadresse, [indeks] erstattes av søkeindeks og [term] erstattes av søkebegrep. Du kan bruke en av følgende indekser:
#•	author
#•	title
#•	keyword
#•	language
#•	type


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