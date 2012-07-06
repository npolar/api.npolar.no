# REST-style API framework

A [Rack](https://github.com/rack/rack)-based framework for running REST-style API endpoints.
You build an API endpoint [lego](http://lego.dk)-wise by feeding the API [core](https://github.com/npolar/api.npolar.no/wiki/Core) a [storage](https://github.com/npolar/api.npolar.no/wiki/Storage) and assembling
middleware authorizers, validators, transformers and observers.

## Basics
### Create
To build an enpoint, simply [`#map`](https://github.com/rack/rack/blob/master/lib/rack/builder.rb) a path
and [`#run`](http://m.onkey.org/ruby-on-rack-2-the-builder) the [`Npolar::Api::Core`]().

``` ruby
# config.ru
map "/ecotox" do
  map "/report" do
    storage = Npolar::Storage::Couch.new("https://username:password@couch.local:6984/ecotox_report")
    run Npolar::Api::Core.new(nil, { :storage => storage }) 
  end
end
```
### Use
A brief usage summary, see [using the API](https://github.com/npolar/api.npolar.no/wiki/Using-the-API) for details:
* `curl -i -X POST` [`/ecotox/report`](http://localhost:9393/ecotox/report) `-d '{}' -H "Content-Type: application/json"`  to create a new (empty) ecotox report
* `curl -i -X PUT` [`/ecotox/report/4cf1ca78.json`](http://localhost:9393/ecotox/report/4cf1ca78.json) `-d '{}'` to create with id
* `curl -i -X GET` [`/ecotox/report`](http://localhost:9393/ecotox/report/) to view all existing ids
* `curl -i -X GET` [`/ecotox/report/4cf1ca78.json`](http://localhost:9393/ecotox/report/4cf1ca78.json) to get a report

## Security
Run the API using transport-level security (TLS/https). 
Make sure to set the `HTTP_X_FORWARDED_PROTO` if you use e.g. [Nginx](http://wiki.nginx.org/HttpSslModule) as a proxy.

### Authentication

### Authorization
Use `Npolar::Auth::Authorizer` for role-based access control.

The [authorizer](https://github.com/npolar/api.npolar.no/wiki/Authorizer) will restrict `GET` and `HEAD` requests to those with a `reader` role,
and `POST`, `PUT`, and `DELETE` to those with a `writer` role.

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
## Configuration

### Core

#### Formats and accepts
It's easy to specify which formats are available (using `:formats`) and accepted (using `:accepts`):
``` ruby
map "/metadata/dataset" do
  storage = Npolar::Storage::Couch.new(config_reader.call("metadata_storage.json"))
  run Npolar::Api::Core.new({:storage => storage,
    :formats=>["atom", "dif", "iso", "json", "solr", "xml"]},
    :accepts => ["dif", "json", "xml"]
  )
end

```

#### Methods

Read-only API. Create a bullet-proof read-only proxy, by allowing only GET and HEAD. 
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
``` http
HTTP/1.1 405 Method Not Allowed
{"error":{"status":405,"reason":"Method Not Allowed"}}
```

## Middleware
#### Transformers
Transformers are Rack middleware that translates between formats before storing 
or, more common, after reading from storage.

For example, if you add `xml` to `:formats` and keep documents in a JSON store like CouchDB,
you can of course store the XML as an attachment or even inline, but often it's
useful to have on-the-fly conversions between different formats.

``` ruby
# config.ru
map "/metadata/dataset" do
  use Api::Rack::Transform::Metadata # transform all :formats but json
  run Npolar::Api::Core.new({:storage => storage, :formats=>["atom", "dif", "iso", "json", "xml"]}, :accepts => ["dif", "json", "xml"])
end
```

#### Validators




## Installation

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
For production, we use unicorn + nginx


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
* Goliath api
# Requirements
* Ruby >= 1.9
