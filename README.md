# REST-style API framework

A [Rack](https://github.com/rack/rack)-based framework for running [REST](http://en.wikipedia.org/wiki/Representational_state_transfer)-style [API](http://en.wikipedia.org/wiki/Application_programming_interface) endpoints.

You build an API endpoint [lego](http://lego.dk)-wise by connecting the API [Core](https://github.com/npolar/api.npolar.no/wiki/Core) a [Storage](https://github.com/npolar/api.npolar.no/wiki/Storage) and assembling
other middleware for security, validation, search-engine indexing, logging, data transformation, etc.

## Basics
### Create
To build an endpoint, simply [`#map`](https://github.com/rack/rack/blob/master/lib/rack/builder.rb) a path,
initialize a storage object and [`#run`](http://m.onkey.org/ruby-on-rack-2-the-builder) a Npolar::Api::Core instance.

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
The `/ecotox/report` API is a CouchDB-backed endpoint which by default accepts and delivers `json` documents.
See [using the API](https://github.com/npolar/api.npolar.no/wiki/Using-the-API) for usage details.

## Security

### Transport-level security
Run all APIs using transport-level security (TLS/https). 
Make sure to set the `HTTP_X_FORWARDED_PROTO` if you use e.g. [Nginx](http://wiki.nginx.org/HttpSslModule) as a proxy.

### Authentication and authorization
Use `Npolar::Rack::Authorizer` for authentication and role-based access control. 

The [Authorizer](https://github.com/npolar/api.npolar.no/wiki/Authorizer) restricts **edits** (`POST`, `PUT`, and `DELETE`) to users with a `editor` role.

The Authorizer needs a backend:
* Use `Npolar::Auth::Ldap` (or [Net::LDAP](http://net-ldap.rubyforge.org/Net/LDAP.html)) to use LDAP
* Use `Npolar::Auth::Couch` for a CouchDB-backed solution

``` ruby
map "/ecotox" do
  map "/report" do

    auth = Npolar::Auth::Lda.new("https://localhost:6984/api_user")
    
    use Npolar::Auth::Authorizer, { :auth => auth, :system => "ecotox" }
    run Npolar::Api::Core.new(nil, { :storage => "https://couch.local:6984/ecotox_report" }) 
  end
end


```
## Configuration

### Formats and accepts
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

### Methods

Read-only API. Create a bullet-proof read-only proxy, by allowing only GET and HEAD. 
``` ruby
# config.ru
map "/api/collection1" do
  storage = Api::Storage::Couch.new("http://localhost:5984/api_collection1")
  run Npolar::Api::Core.new(nil, {:storage => storage, :methods => ["HEAD", "GET"], :formats => ["json"]}) 
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

### Validators

### Transformers
Transformers are Rack middleware that translates between formats before storing 
or, more common, after reading from storage.

For example, if you add `xml` to `:formats` and keep documents in a JSON store like CouchDB,
you can store the XML as an attachment or even inline, but often it's more convenient
to have on-the-fly conversions between different formats.

``` ruby
# config.ru
map "/metadata/dataset" do
  use Metadata::Rack::Transform # transform all :formats but json
  run Npolar::Api::Core.new(nil, config)
end
```
### Observers

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
For production, we use [unicorn]() behind [nginx]()

## Features

**Powerful**
* Store any kind of document (JSON, XML, HTML, text, media/files)
* [Great search](http://lucene.apache.org/solr/) with facets/filters on any document attribute
* Customizable validation
* Customizable transformation/processing
* Permanent addresses (URIs/IRIs)
* Multiple formats (in/out)
* Role-based access control
* Revisions: complete document history (edit log)

**Flexible**
* Choose your own storage strategy (per collection/per server)
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