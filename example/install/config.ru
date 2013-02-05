# encoding: utf-8
# This config.ru is the *production* configuration for api.npolar.no
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require "./load"

Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"]
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"]

Metadata::Dataset.formats = ["json", "dif", "iso", "atom"]
Metadata::Dataset.accepts = ["json", "xml"]


# Middleware for *all* requests - use with caution
# a. Security
# use Rack::Throttle::Hourly,   :max => 1200 # requests
# use Rack::Throttle::Interval, :min => 110.1 # seconds
# use Npolar::Rack::SecureEdits (force TLS/SSL ie. https)

# b. Features
use Rack::JSONP
use Rack::Static, :urls => ["/css", "/img", "/xsl", "/favicon.ico", "/robots.txt"], :root => "public"
# use Npolar::Rack::Editlog, Npolar::Storage::Solr.new("/api/editlog"), except => ["/path"]
# use Npolar::Rack::Editlog, Npolar::Storage::Couch.new("/api/editlog"), except => ["/path"]

# http(s)://api.npolar.no/
# 
# Please keep all map statements below in alphabetical order
map "/" do

  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"),
    :system => "api", :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin"),
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method }
  }

  use Views::Api::Index

  use Npolar::Rack::Atomizer

  run Npolar::Rack::Solrizer.new(nil, {
    :core => "api",
    :facets => Npolar::Api.facets
    # Convert from Atom-like JSON => Solr JSON "
  })

  # The map sections below are for the internal "api" workspace
  map "/parameter" do
  end

  # /schema
  # @todo Setup storage with revisions
  map "/schema" do
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"),
      :system => "api", :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin"),
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method }
    }
    run Npolar::Api::Core.new(nil, {:storage => Npolar::Storage::Couch.new("schema"), :formats => ["html", "json"]})
  end
  
  map "/service" do

    use Npolar::Rack::Solrizer, { :core => "api",
      :facets => ["formats", "accepts", "path", "methods", "person", "methods", "protocols", "relations", "project", "group", "set", "category", "editor", 
"tags", "groups", "licences"],
      :fq => ["workspace:api", "collection:service"],
      #:fields => "title"
    }

    use Views::Api::Index

    # use AtomPubService
    # http://tools.ietf.org/html/rfc5023#section-8

    run Npolar::Api::Core.new(nil, { :storage => Npolar::Storage::Couch.new("api")})

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

  run Npolar::Api::Core.new(Views::Biology::Index.new, :storage => nil, :methods =>  ["GET", "HEAD"])
    solrizer = Npolar::Rack::Solrizer.new(nil, {:core => "http://olav.npolar.no:8080/solr/marine_database",
    :facets => ["collection", "station_ss", "year_ss", "animalgroup_ss", "programs_sms", "species_sms", "species_groups_sms", "sample_types_sms", "long_fs", "lat_fs"]})
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
  index = Views::Metadata::Index.new
  solrizer = Npolar::Rack::Solrizer.new(index, { :core => "http://olav.npolar.no:8080/pmdb/",
    :fq => ["type:Data*"], :facets => ["region", "institution_long_name"]})

  run index

  map "/oai" do
    run Npolar::Rack::OaiSkeleton.new(Views::Api::Index.new, :provider => Metadata::OaiRepository.new)
  end

  map "/dataset" do
    
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "metadata",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }

    index = Views::Api::Index.new

    model = Metadata::Dataset.new

    storage = Npolar::Storage::Couch.new("metadata_dataset")
    storage.model = model
    
    # DIF XML <--> JSON
    use Metadata::Rack::DifJsonizer

    #use Npolar::Rack::JsonValidator

    use Views::Api::Index
    # Solr search (GET)
    # Solr save (POST, PUT)
    # Solr delete (DELETE)
    # HOW to post! example!
    use Npolar::Rack::Solrizer, { :core => "api",
      :facets => Metadata::Dataset.facets,
      :fq => ["workspace:metadata", "collection:dataset"],
      :to_solr => lambda {|hash|
      
          model = Metadata::Dataset.new(hash)
          model.to_solr        
      }
    }

    run Npolar::Api::Core.new(nil,
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

# @todo decide collections ie. paths
map "/oceanography" do

  #map "/cruise"
  #map 
  # Show ocean index on anything that is not a search
  run Npolar::Rack::Solrizer.new(Views::Ocean::Index.new, :core => "http://localhost:8983/solr", :select => "select")
end

# @todo fork?
map "/org" do
  solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://bjarne.npolar.no:8983/solr/",
    :fq => ["type:Institution"], :facets => ["region", "institution_short_name", "city", "state_or_province", "country"]})
  run Views::Api::Index.new(solrizer)
end

# @todo fork and merge with LDAP users, create pipeline
map "/person" do
  solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://bjarne.npolar.no:8983/solr/",
    :fq => ["type:Person"], :facets => ["region", "institution_short_name"]})
  run Views::Api::Index.new(solrizer)
end

#
map "/project" do
  solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://bjarne.npolar.no:8983/solr/",
    :fq => ["type:Project"], :facets => ["region", "location_exact", "institution_short_name", "status"]})
  run Views::Api::Index.new(solrizer)
end

# 
map "/placename" do
  solrizer = Npolar::Rack::Solrizer.new(nil, {
    :select => "select",
    #:core => "http://localhost:8983/solr/api",
    :core => "http://olav.npolar.no:8080/solr/geonames",

    # New core (not-yet ready):
    #:core => "http://dbmaster.data.npolar.no:8983/solr/placename",
    :fq => ["workspace:geo", "collection:geoname"],
    :summary => lambda {|doc| doc["definition"] },
    :facets => ["location", "hemisphere", "approved", "terrain", "country", "map", "reference", "north", "east"]
  })
  run Views::Api::Index.new(solrizer)
end

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

map "/polarbear" do

  map "/interaction" do

    use Views::Api::Index

    use Npolar::Rack::Solrizer, { :core => "polarbear_interaction",
      :facets => Polarbear::Interaction.facets,
      :to_solr => Polarbear::Interaction.to_solr_lambda
  } 
  run Npolar::Api::Core.new(nil, :storage => Npolar::Storage::Couch.new("polarbear_interaction"))
 
  end

  map "/reference" do
    solrizer = Npolar::Rack::Solrizer.new(nil, { :core => "http://localhost:8983/solr/pbsg_reference",
    :facets => ["source", "year", "periodical", "keyword", "author_exact"]
})
    run Views::Api::Index.new(solrizer)
  end
end

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
