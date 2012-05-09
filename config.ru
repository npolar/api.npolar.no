# config.ru

require "./lib/api/server"
require "./lib/api/collection"
require "./lib/metadata/rack/gcmd_dif"
require "./lib/metadata/rack/save_gcmd_dif"
require "./lib/api/storage"
require "./lib/api/storage/couch"
require "rack/contrib/jsonp"

# Rack middleware
#use Rack::ShowExceptions
#use Rack::JSONP
#use Rack::ConditionalGet
#use Rack::ETag
#use Rack::Lint

config_hash = JSON.parse(IO.read(File.join(".", "config", "config.json")))


map "/metadata/dataset" do
    config = config_hash["paths"]["/metadata/dataset"]
    storage = Api::Storage.factory(config["storage"], config["storage_config"])
    collection = Api::Collection.new(storage) # => factory
            
    server = Api::Server.new
    server.collection = collection    
    
    use Metadata::Rack::SaveGcmdDif
    use Metadata::Rack::GcmdDif    

    run server

end




hello = lambda do |env|
  script = env["SCRIPT_NAME"]
  agent = env["HTTP_USER_AGENT"]
  out = "<h1>Hello world</h1><p>env[\"HTTP_USER_AGENT\"] = #{agent.to_json}</p>"
  return [200, {"Content-Type" => "text/html"}, [out]]
end

map "/hello" do
  run hello
end


# "finding" by code/id unkwown collection cascading?
# Rack::Cascade tries an request on several apps, and returns the
  # first response that is not 404 (or in a list of configurable
  # status codes).