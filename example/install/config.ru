require "./load"
# This config.ru is the production configuration for api.npolar.no
# Please keep all map statements in alphabetical order

Npolar::Api.workspaces = ["biology", "ecotox", "gcmd", "map", "metadata", "placename", "ocean", "seaice", "tracking"]

Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"]
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"]

Metadata.collections = ["dataset"]
Seaice.collections = ["black-carbon", "em31", "thickness-drilling", "core", "snowpit"]

Metadata::Dataset.formats = ["atom", "dif", "html", "iso", "json", "xml"]
Metadata::Dataset.accepts = ["dif", "json"]

use Rack::JSONP
use Rack::Static, :urls => ["/css", "/img", "/xsl", "/favicon.ico", "/robots.txt"], :root => "public"
# use Npolar::Rack::SecureEdits
# use Npolar::Rack::Editlog, Npolar::Storage::Couch.new("api_editlog")

map "/" do
  # http(s)://api.npolar.no/
  # Show index view on anything that is not a global search
  run Npolar::Rack::Solrizer.new(Views::Api::Index.new, :core => "")
  
  # The map sections below are for the internal "api" workspace
  map "/schema" do
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"),
      :system => "api", :authorized? => Npolar::Rack::Authorizer.authorize("sysadmin"),
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method }
    }
    run Npolar::Api::Core.new(nil, {:storage => Npolar::Storage::Couch.new("schema"), :formats => ["html", "json"]})
  end

  map "/user" do
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "api", :authorized? =>  lambda {
      | auth, system, request | auth.roles(system).include? Npolar::Rack::Authorizer::SYSADMIN_ROLE }
    }
    run Npolar::Api::Core.new(nil, {:storage => Npolar::Storage::Couch.new("api_user"), :methods => ["GET", "HEAD", "POST", "PUT"]}) # No DELETE
  end
end


map "/biology/observation" do

  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "biology",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }

  use Npolar::Rack::Solrizer, { :core => "", :fq => ["workspace:biology", "collection:observation"]}

  run Npolar::Api::Core.new(nil, :storage =>Npolar::Storage::Couch.new("observation_fauna"))
end


map "/ecotox" do
  # Show ecotox index on anything that is not a search
  run Npolar::Rack::Solrizer.new(Views::Ecotox::Index.new, :core => "" )

  map "/report" do
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "ecotox",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method }
    }
    #use Npolar::Rack::TikaExtracter
    run Npolar::Api::Core.new(nil, :storage => Npolar::Storage::Couch.new("ecotox"))

  end
end

map "/gcmd" do

  gcmd_index = lambda {|env|
    index = Gcmd::Index.new
    index[:scheme] = Rack::Request.new(env)["scheme"] ||= "locations"
    [200, {"Content-Type" => "text/html"},[index.render]]
  }
  run gcmd_index
  concepts = Gcmd::Concepts.new
  
  Gcmd::Concepts::ROOT_SCHEMES.each do |scheme|
    map "/#{scheme}" do

      use Npolar::Rack::RequireParam, :params => ["q"]
      use Rack::JSONP

      gcmd_concept = lambda {|env|
        q = Rack::Request.new(env)["q"]
        [200, {"Content-Type" => "application/json"},[concepts.filter(scheme, q).to_json]]
      }
      run gcmd_concept
    
    end
  end
end

map "/map" do

  run Npolar::Rack::Solrizer.new(Views::Map::Index.new, :core => "")

  map "/archive" do
    run Npolar::Rack::Solrizer.new(
      Views::Map::Index.new,
      { :core => "http://olav.npolar.no:8080/solr/map_archive"}
    )
  end
end


map "/metadata" do

  # Show metadata index on anything that is not a search
  run Npolar::Rack::Solrizer.new(Views::Metadata::Index.new, :core => "")

  map "/oai" do
    run Npolar::Rack::OaiSkeleton.new(Views::Api::Index.new, :provider => Metadata::OaiRepository.new)
  end

  map "/dataset" do

    model = Metadata::Dataset.new
    #model.schema = File.read(File.expand_path(File.join(".", "lib", "metadata/dataset-schema.json")))
    #p model.schema

    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "metadata",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
  
    use Metadata::Rack::DifJsonizer

    use Npolar::Rack::Solrizer, { :core => "", :model => model }

    run Npolar::Api::Core.new(Views::Metadata::Index.new,
      { :storage => Npolar::Storage::Couch.new("metadata_dataset"),
        :formats => Metadata::Dataset.formats,
        :accepts => ["json", "dif", "xml"]
      }
    )
  end
end

map "/ocean" do
  # Show ocean index on anything that is not a search
  run Npolar::Rack::Solrizer.new(Views::Ocean::Index.new, :core => "")
end

map "/person" do
  run Npolar::Rack::Solrizer.new(Views::Api::Index.new,
    { :core => "http://olav.npolar.no:8080/pmdb/", :fq => ["type:Person"]}
  )
end

map "/placename" do
  run Npolar::Rack::Solrizer.new(Views::Api::Index.new, {  :select => "select", :fq => ["workspace:geo", "collection:geoname"],
    :summary => lambda {|doc| doc["definition"] }
  })
end


map "/seaice" do
  # Show seaice index on anything that is not a search
  run Npolar::Rack::Solrizer.new(Views::Seaice::Index.new, :core => "/")

  Seaice.collections.each do |scheme|
    map "/#{scheme}" do

      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("api_user"), :system => "seaice",
        :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }

      run Npolar::Api::Core.new(nil, :storage => Npolar::Storage::Couch.new("seaice"))
    
    end
  end
end

map "/tracking" do
  # Show tracking index on anything that is not a search
  run Npolar::Rack::Solrizer.new(Views::Tracking::Index.new, :core => "")
  
end
