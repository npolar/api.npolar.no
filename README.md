# REST-style API kit

A [Rack](https://github.com/rack/rack)-based kit for running [REST](http://en.wikipedia.org/wiki/Representational_state_transfer)-style [API](http://en.wikipedia.org/wiki/Application_programming_interface)s.

Create API endpoints [lego](http://lego.dk)-wise by connecting a [Npolar::Api::Core](https://github.com/npolar/api.npolar.no/wiki/Core) instance with a [Storage](https://github.com/npolar/api.npolar.no/wiki/Storage) object and assembling
other middleware for security, validation, search/indexing, logging, transformation, etc.

## Basics

* [Install](https://github.com/npolar/api.npolar.no/wiki/Install)

### Create

``` ruby
# config.ru
map "/arctic/animal" do
  storage = Npolar::Storage::Couch.new("https://username:password@couch.local:6984/arctic_animal")
  run Npolar::Api::Core.new(nil, { :storage => storage }) 
end
```
`/arctic/animal` is now a CouchDB-backed API that accepts and delivers [`JSON`](http://json.org) documents.

### PUT
``` http
curl -i -X PUT http://example.com/arctic/animal/polar-bear.json -d'{"id": "polar-bear", "species":"Ursus maritimus" "en": "Polar bear"}'
curl -i -X PUT http://example.com/arctic/animal/walrus.json -d'{"id": "walrus", "species":"Odobenus rosmarus" "en": "Walrus"}'
```

### GET

See [using the API](https://github.com/npolar/api.npolar.no/wiki/Using-the-API) for further details.

## Security

### Transport-level security
Make sure to run all APIs that require authentication and/or authorization using transport-level security (TLS/https). 
If you use [nginx](http://wiki.nginx.org/HttpSslModule) https, remember to set the `HTTP_X_FORWARDED_PROTO`.

### Authentication and authorization
Use `Npolar::Rack::Authorizer` for authentication and simple role-based access control. 

The [Authorizer](https://github.com/npolar/api.npolar.no/wiki/Authorizer) restricts **editing** (`POST`, `PUT`, and `DELETE`) to users with a `editor` role.
and **reading** to users with a `reader` role.

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

For **free/open data**, you might want to loosen security by allowing anyone to read. Easy using `:except?`
``` ruby
  use Npolar::Rack::Authorizer, { :auth => api_user, :system => "metadata",
    :except? => lambda {|request| ["GET", "HEAD"].include? request.request_method } }
```
## Configuration

### Formats and accepts
Specify available outgoing formats (using `:formats`) and accepted incoming formats (using `:accepts`):

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
For production, we recommend and use 

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