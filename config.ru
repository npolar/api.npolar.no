require "./start"

config_reader = lambda {|filename| JSON.parse(File.read(File.join(".", "config", filename))) }
config_loader = lambda {|filename| eval(File.open(File.expand_path("./config/#{filename}")).read) }

api_user = Npolar::Auth::Couch.new(config_reader.call("api_user_storage.json"))
ldap = Npolar::Auth::Ldap.new(config_loader.call("ldap.rb"))

map "/api" do
  map "/user" do
    use Npolar::Rack::Authorizer, { :auth => api_user, :system => "api" }
    run Npolar::Api::Core.new(nil, {:storage => api_user, :methods => ["GET", "HEAD", "POST", "PUT"]}) # No DELETE
  end
end

map "/gcmd" do

  gcmd_index = lambda {|env|
    scheme = Rack::Request.new(env)["scheme"] ||= "locations"
    index = Gcmd::Index.new
    index[:scheme] = scheme
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

map "/metadata/dataset" do

  use Npolar::Rack::Authorizer, { :auth => api_user, :system => "metadata",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }

  use Metadata::Rack::Dif

  run Npolar::Api::Core.new(nil,
    { :storage => Npolar::Storage::Couch.new(config_reader.call("metadata_storage.json")),
      :formats => ["atom", "dif", "iso", "json", "xml"],
      :accepts => ["json", "dif", "xml"]
    }
  )
  # a nice way to validate all docs?
end

map "/observation/fauna" do
  storage = Npolar::Storage::Couch.new(config_reader.call("observation_fauna_storage.json"))
  run Npolar::Api::Core.new(nil, :storage => storage)
end

# @todo Rack::Static, :urls => ["/xsl"], :root => "public"
# @todo Use Rack:Cascade to find by UUID/code
# @todo Validate agent-ip-username
