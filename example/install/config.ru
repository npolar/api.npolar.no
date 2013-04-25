# encoding: utf-8
# This config.ru is the *production* configuration for api.npolar.no

# Set internal and external encoding for the application
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Initialize environment
ENV['GCMD_HTTP_USERNAME'] = ""
ENV['GCMD_HTTP_PASSWORD'] = ""
ENV['NPOLAR_API_COUCHDB'] = ""
ENV['NPOLAR_API_SOLR'] = ""
ENV['NPOLAR_API_ELASTICSEARCH'] = ""

LDAP_CONF = {
  :host => "",
  :port => 389,
  :base => "",
  :auth => { :username => "", :password => "", :method => :simple }
}

require "./load"

Npolar::Storage::Couch.uri = ENV["NPOLAR_API_COUCHDB"]
Npolar::Rack::Solrizer.uri = ENV["NPOLAR_API_SOLR"]

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

# Base Path
map "/" do

  #use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
  #  :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }  

  run lambda{|env| [200,{"Content-Type" => "application/json"},[{"endpoints" => ["data", "project", "publication", "resource", "schema", "service"]}.to_json]]}

  map "/data" do

    run lambda{|env| [200,{"Content-Type" => "application/json"},[{"endpoints" => ["description", "glaciology", "oceanography", "telemetry", "topography"]}.to_json]]}
    
    map "/biology" do
      
    end
    
    map "/description" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
      
      #use Metadata::Rack::IsoJson
      use Metadata::Rack::DifJsonizer
      use Npolar::Rack::JsonCleaner
      use Npolar::Rack::JsonValidator, {:schema => ["schema/dataDescriptionArray.json", "schema/dataDescription.json", "schema/minimalDataDescription.json"]}
      #use Npolar::Rack::RubberBand
      use Npolar::Rack::ChangeLogger, {:data_storage => Npolar::Storage::Couch.new("data_description"), :diff_storage => Npolar::Storage::Couch.new("description_revision")}
      
      run Npolar::Api::Core.new(nil,
        { :storage => Npolar::Storage::Couch.new("data_description"),
          :formats => ['json'],
          :accepts => ['json']
        }
      )
    end
    
    map "/glaciology" do

      use Npolar::Rack::AttachmentDownloader, {:database => "glaciology"}
      use Npolar::Rack::IceLastic, {:facets => ['grid', 'sensor_name', 'collection', 'topic', 'primary_data']}
      
      run Npolar::Api::Core.new(nil,
        { :storage => Npolar::Storage::Couch.new("glaciology"),
          :formats => ['json'],
          :accepts => ['json']
        }
      )
      
      map "/gps" do
        
        run Npolar::Api::Core.new(nil,
          { :storage => Npolar::Storage::Couch.new("glaciology"),
            :formats => ['json'],
            :accepts => ['json']
          }
        )
        
        map "/position" do
        
          use Npolar::Rack::JsonValidator, {:schema => ["schema/gpsArray.json", "schema/gps.json"]}
          
          run Npolar::Api::Core.new(nil,
            { :storage => Npolar::Storage::Couch.new("glaciology"),
              :formats => ['json'],
              :accepts => ['json']
            }
          )
        
        end
      
      end
      
    end
    
    map "/image" do
      
      map "/webcam" do
        
        run Npolar::Api::Core.new(nil,
          { :storage => Npolar::Storage::Couch.new("images"),
            :formats => ['json'],
            :accepts => ['json']
          }
        )
        
      end
      
    end
    
    map "/oceanography" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
      
      map "/ctd" do
        use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
          :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
        
        run Npolar::Api::Core.new(nil,
          { :storage => Npolar::Storage::Couch.new("oceanography_ctd"),
            :formats => ['json'],
            :accepts => ['json']
          }
        )
      end
      
    end
    
    map "/telemetry" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    end
    
    map "/topography" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    end
    
    map "/seaice" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    end

  end
  
  map "/project" do
  
    run lambda{|env| [200,{"Content-Type" => "application/json"},[{"endpoints" => ["description", "rapport"]}.to_json]]}
  
    map "/description" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    end
    
    map "/rapport" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    end
  
  end

  map "/publication" do
  
    run lambda{|env| [200,{"Content-Type" => "application/json"},[{"endpoints" => ["description", "doc"]}.to_json]]}
  
    map "/description" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    end
    
    map "/doc" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    end
  
  end
  
  map "/resource" do
  
    run lambda{|env| [200,{"Content-Type" => "application/json"},[{"endpoints" => ["org", "person", "sensor"]}.to_json]]}
  
    map "/org" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    end
    
    map "/person" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    end
    
    map "/sensor" do
      use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    end
  
  end
  
  map "/schema" do
    use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Ldap.new(LDAP_CONF), :system => "api",
      :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
    
    run Npolar::Api::Core.new(nil,
      { :storage => Npolar::Storage::Couch.new("schema"),
        :formats => ['json'],
        :accepts => ['json']
      }
    )
  end

end
