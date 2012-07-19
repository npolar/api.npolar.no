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

map "/metadata/dataset" do
  storage = Npolar::Storage::Couch.new(config_reader.call("metadata_storage.json"))
  use Metadata::Rack::Dif
  run Npolar::Api::Core.new(nil, {:storage => storage, :formats=>["atom", "dif", "iso", "json", "xml"]})

end

map "/observation/fauna" do
  storage = Npolar::Storage::Couch.new(config_reader.call("observation_fauna_storage.json"))
  run Npolar::Api::Core.new(nil, :storage => storage)
end

# @todo Rack::Static, :urls => ["/xsl"], :root => "public"
# @todo Use Rack:Cascade to find by UUID/code
# @todo Validate agent-ip-username
