# REST-style API framework

A [Rack](https://github.com/rack/rack)-based framework for running [REST](http://en.wikipedia.org/wiki/Representational_state_transfer)-style [API](http://en.wikipedia.org/wiki/Application_programming_interface) endpoints.

You build an API endpoint [lego](http://lego.dk)-wise by connecting the [Core](https://github.com/npolar/api.npolar.no/wiki/Core) with a [Storage](https://github.com/npolar/api.npolar.no/wiki/Storage) object and assembling
other middleware for security, validation, searching, indexing, logging, transformation, etc.

## Basics
### Create
To build an endpoint, simply [`#map`](https://github.com/rack/rack/blob/master/lib/rack/builder.rb) a path,
initialize a storage object and [`#run`](http://m.onkey.org/ruby-on-rack-2-the-builder) a `Npolar::Api::Core` instance.

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
The `/ecotox/report` API is now a CouchDB-backed endpoint which by default accepts and delivers `json` documents.
See [using the API](https://github.com/npolar/api.npolar.no/wiki/Using-the-API) for usage details.

## Security

### Transport-level security
Make sure to run all APIs that require authentication and/or authorization using transport-level security (TLS/https). 
if you use [Nginx](http://wiki.nginx.org/HttpSslModule), or other proxies, remember to set the `HTTP_X_FORWARDED_PROTO`.

### Authentication and authorization
Use `Npolar::Rack::Authorizer` for authentication and simple role-based access control. 

The [Authorizer](https://github.com/npolar/api.npolar.no/wiki/Authorizer) restricts **editing** (`POST`, `PUT`, and `DELETE`) to users with a `editor` role,
and **reading** (`GET`/`HEAD`) to `reader`s.

The Authorizer needs an Auth backend, see
* `Npolar::Auth::Ldap` (or [Net::LDAP](http://net-ldap.rubyforge.org/Net/LDAP.html)) for LDAP authentication (authorization is @todo)
* `Npolar::Auth::Couch` for a CouchDB-backed solution

``` ruby
map "/ecotox" do
  map "/report" do

    auth = Npolar::Auth::Couch.new("https://localhost:6984/api_user")
    
    use Npolar::Auth::Authorizer, { :auth => auth, :system => "ecotox" }
    run Npolar::Api::Core.new(nil, { :storage => "https://couch.local:6984/ecotox_report" }) 
  end
end

```

You can modify the behavior of the Authorizer by injecting lambda functions.

For example, here is how you can **tighten security** to users with a `sysadmin` role:

``` ruby
  use Npolar::Rack::Authorizer, { :auth => Npolar::Auth::Couch.new("https://localhost:6984/api_user"), :system => "api", :authorized? =>
      lambda { | auth, system, request | auth.roles(system).include? Npolar::Rack::Authorizer::SYSADMIN_ROLE }
  }
```

For **free data**, you might want to loosen security by allowing anyone to read. Easy using `:except?`
``` ruby
  use Npolar::Rack::Authorizer, { :auth => api_user, :system => "metadata",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
```

## Configuration

### Formats and accepts
Specify which formats are available (using `:formats`) and accepted (using `:accepts`):

``` ruby
map "/metadata/dataset" do
  storage = Npolar::Storage::Couch.new(config_reader.call("metadata_storage.json"))
  run Npolar::Api::Core.new({:storage => storage,
    :formats=>["atom", "dif", "iso", "json", "solr", "xml"]},
    :accepts => ["dif", "json", "xml"]
  )
end

```

### Methods

Use `:methods` to configure allowed HTTP verbs. Create a bullet-proof read-only API, by allowing only GET and HEAD. 

``` ruby
# config.ru
map "/api/collection1" do
  storage = Api::Storage::Couch.new("http://localhost:5984/api_collection1")
  run Npolar::Api::Core.new(nil, {:storage => storage, :methods => ["HEAD", "GET"]) 
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

### Solrizer
[Solrizer]() provides search and indexing capabilities to any collection.

Automatic filtering: Combine fulltext search with filtering/faceting on every
document attribute.

Automatic indexing: Feed the solrizer with a model object (that contains a `#to_solr` method)
and it will add documents to the Solr index on every POST or PUT, and remove them on DELETE.


## Installation
Requirements:
* Ruby >= 1.9
* Probably Linux, CouchDB, Git, Solr and Nginx as well :)

``` sh
$ git clone git@github.com:npolar/api.npolar.no.git
$ cd api.npolar.no
$ bundle install
$ rspec
```

### Start (development)
``` sh
$ bundle exec shotgun -d # http://localhost:9393
```
For production, we recommend and use [unicorn](http://unicorn.bogomips.org/) behind [nginx](http://nginx.org/)

## Features

**Powerful**
* Store any kind of document (JSON, XML, HTML, text, media/files)
* Great [Solr](http://lucene.apache.org/solr/) search: facets/filters on any document attribute
* Customizable validation
* Customizable transformation/processing
* Permanent addresses (URIs/IRIs)
* Multiple formats (in/out)
* Role-based access control
* Revisions: complete document history (edit log)

**Flexible**
* Choose your own storage strategy (per system/per collection)
* Choose your own storage 
* Choose your own resource paths
* Choose your own authorization strategy

**Extensible**
* Object-oriented and extensible code
* Modular design with dependency injection of major components
* Easy to implement domain logic (per collection/per server)

**Scalable**
* Stateless
* Cacheable

**Testable**
* Test-first development strategy