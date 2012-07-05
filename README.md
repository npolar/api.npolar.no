# REST-style API framework
[![Build Status](https://secure.travis-ci.org/npolar/rack-throttle.png)](https://secure.travis-ci.org/npolar/rack-throttle)

`Npolar::Api::Core` is [Rack](https://github.com/rack/rack) class for running REST-like API endpoints.

## Operation guide
See also [Using the API]

#### Create API
You need: a path (for [cool URIs](http://www.w3.org/TR/cooluris/)) - and a [storage]() object:
``` ruby
map "/ecotox" do
  map "/report" do
    storage = Npolar::Storage::Couch.new("https://username:password@couch.local:6984/ecotox_report")
    run Npolar::Api::Core.new(nil, { :storage => "https://couch.local:6984/ecotox_report" }) 
  end
end
```

#### Security

Use `Npolar::Auth::Authorizer` for role-based access control. The authorizer will
restrict GET and HEAD requests to those with a `reader` role, and POST, PUT, and
DELETE to those with a `writer` role.

``` ruby
map "/ecotox" do
  map "/report" do

    storage = Npolar::Storage::Couch.new("https://localhost:6984/ecotox_report")
    auth = Npolar::Auth::Couch.new("https://localhost:6984/api_user")
    
    use Npolar::Auth::Authorizer, { :auth => auth, :system => "ecotox" }
    run Npolar::Api::Core.new(nil, { :storage => "https://couch.local:6984/ecotox_report" }) 
  end
end
```

The security stack consists of three layers
* Check user credentials, but only over secure transport (https/SSL) - or else [401]
* Check that user/group/application is authorized - or else [403]
* Check document-level access rights - or else [403]  


#### Storage


#### Formats

`:formats` = available response formats.
`:accepts` = which formats the endpoint will accept (in the POST or PUT body)

``` ruby
map "/metadata/dataset" do
  storage = Npolar::Storage::Couch.new(config_reader.call("metadata_storage.json"))
  run Npolar::Api::Core.new({:storage => storage, :formats=>["atom", "dif", "iso", "json", "xml"]}, :accepts => ["dif", "json", "xml"])
end

```

#### Transformers

If you add "xml" to :formats and keep documents in a JSON store like CouchDB,
you can of course store the XML as an attachment or even inline, but often it's
useful to have on-the-fly conversions between different formats.

Transformers are Rack middleware that translates the response from from a storage format
to a response format.

``` ruby
# config.ru
map "/metadata/dataset" do
  use Api::Rack::Transform::Metadata # transform all :formats but json
  run Npolar::Api::Core.new({:storage => storage, :formats=>["atom", "dif", "iso", "json", "xml"]}, :accepts => ["dif", "json", "xml"])
end
```
#### Processors

Processors are request transformers.

#### Validators

#### Auth

#### Security

#### Install

``` sh
$ git clone git@github.com:npolar/api.npolar.no.git
$ cd api.npolar.no
$ bundle install
$ rspec
```

#### Start (development)
``` sh
$ bundle exec shotgun -d # http://localhost:9393
```
For production, use unicorn + nginx

#### Read-only API

Create a read-only CouchDB proxy, by allowing only HTTP GET and HEAD. 
``` ruby
# config.ru
map "/api/collection1" do
  storage = Api::Storage::Couch.new("http://localhost:5984/api_collection1")
  run Npolar::Api.app, {:storage => storage, :methods => ["HEAD", "GET"], :formats => ["json"]} 
end
```

``` sh
$ curl -i -XPOST http://localhost:9393/api/read-only/ -d '{}'
```

``` json
HTTP/1.1 405 Method Not Allowed

{"error":{"status":405,"reason":"Method Not Allowed"}}
```



# api.npolar.no

## Features

Powerful
* Store any kind of document (JSON, XML, HTML, text, media/files)
* Great search with facets/filters on any document attribute
* Customizable validation
* Customizable transformation/processing
* Permanent addresses (URIs/IRIs)
* Multiple formats (in/out)
* Access control
* Revisions: complete document history (edit log)

Flexible
* Choose your own storage strategy (per collection/per server)
* Choose your own storage 
* Choose your own resource paths
* Choose your own authorization strategy

Extensible
* Object-oriented and extensible code
* Modular design with dependency injection of all components
* Easy to implement domain logic (per collection/per server)

Scalable
* Stateless design
* Cacheable

Testable
* Test-first development strategy
* Aims for 100% test coverage



## Similar projects
* GRAPE
* https://github.com/olivernn/rackjson
* https://github.com/fnando/rack-api

# Requirements
* Ruby >= 1.9
goliath api