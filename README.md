# REST API powering http://api.npolar.no

[Rack](https://github.com/rack/rack)-based building blocks for running [REST](http://en.wikipedia.org/wiki/Representational_state_transfer)-style [API](http://en.wikipedia.org/wiki/Application_programming_interface)s.

Construct API endpoints [lego](http://lego.dk)-wise by connecting a [Npolar::Api::Core](https://github.com/npolar/api.npolar.no/wiki/Core) instance with a [Storage](https://github.com/npolar/api.npolar.no/wiki/Storage) object and assembling
other [middleware](https://github.com/npolar/api.npolar.no/wiki/Middleware) for security, validation, search/indexing, logging, transformation, etc.

## Basics

``` ruby
# config.ru
map "/arctic/animal" do 
  storage = Npolar::Storage::Couch.new("https://username:password@ocalhost:6984/arctic_animal")
  run Npolar::Api::Core.new(nil, { :storage => storage }) 
end
```
`/arctic/animal` is now a CouchDB-backed HTTP-driven document API that accepts and delivers [JSON](http://json.org) documents.

## Document API
The document API follows key aspects of the [HTTP](http://www.w3.org/Protocols/rfc2616/rfc2616.html) 1.1 protocol, in particular careful use of HTTP status codes.

### Create (PUT)

``` http
curl -i -X PUT http://localhost:9393/arctic/animal/polar-bear.json -d'{"id": "polar-bear", "species":"Ursus maritimus"}'
HTTP/1.1 201 Created
Content-Type: application/json

{
  "_id": "polar-bear",
  "_rev": "1-9c8fb39bfacc81cc5e39610f9cf81df2",
  "id": "polar-bear",
  "species": "Ursus maritimus"
}
```

### Create (POST)
``` http
curl -i -X POST http://localhost:9393/arctic/animal/.json -d '{"species":"Odobenus rosmarus", "en": "Walrus"}'
HTTP/1.1 201 Created

{"_id":"d5fbc7e78bcb21836abf82a96c0009e9","_rev":"1-b3917c5de68075fea8c0e83311c8ad39","species":"Odobenus rosmarus","en":"Walrus"}

```

### Retrieve (GET)

#### List documents

``` http
curl -i -X GET http://localhost:9393/arctic/animal/.json

["d5fbc7e78bcb21836abf82a96c000182", "polar-bear"]

```

#### Get document
``` http
curl -i -X GET http://localhost:9393/arctic/animal/d5fbc7e78bcb21836abf82a96c000182.json
HTTP/1.1 200 OK

{"_id":"d5fbc7e78bcb21836abf82a96c000182","_rev":"1-b3917c5de68075fea8c0e83311c8ad39","species":"Odobenus rosmarus","en":"Walrus"}

```

### Update (PUT)

``` http
curl -i -X PUT http://localhost:9393/arctic/animal/polar-bear.json -d'{"_id":"polar-bear","_rev":"1-9c8fb39bfacc81cc5e39610f9cf81df2","id":"polar-bear","species":"Ursus maritimus", "en": "Polar bear", "nn": "Isbjørn", "nb":"Isbjørn"}'
```
The above works '''once''' because the document body contains the correct revision. If you replay the PUT, you will get a HTTP `409` Conflict error, see
[Revisions]() for how to deal with this.
.)

``` http
curl -i -X PUT http://localhost:9393/arctic/animal/polar-bear.json -d '{}'
HTTP/1.1 409 Conflict
```

### Delete

``` http
curl -X DELETE http://localhost:9393/arctic/animal/d5fbc7e78bcb21836abf82a96c000182.json?rev=1-b3917c5de68075fea8c0e83311c8ad39
```
Again, attempting to delete without a revision, or with the wrong revision, leads to a HTTP `409` Conflict response.


## Security

### Transport-level security
Make sure to run all APIs that require authentication and/or authorization using transport-level security (TLS/https),
see [Install] for how you might set this up using Nginx and Unicorn.

### Authentication and authorization
Use `Npolar::Rack::Authorizer` for authentication and simple role-based access control. 

The [Authorizer](https://github.com/npolar/api.npolar.no/wiki/Authorizer) restricts **editing** (`POST`, `PUT`, and `DELETE`) to users with a `editor` role.
and **reading** to users with a `reader` role.

The Authorizer needs an Auth backend, see
* `Npolar::Auth::Ldap` (or [Net::LDAP](http://net-ldap.rubyforge.org/Net/LDAP.html)) for LDAP authentication (authorization is @todo)
* `Npolar::Auth::Couch` for a CouchDB-backed solution

``` ruby
map "/arctic/animal" do 
  auth = Npolar::Auth::Couch.new("https://localhost:6984/api_user")    
  use Npolar::Auth::Authorizer, { :auth => auth, :system => "arctic_animal" }
  run Npolar::Api::Core.new(nil, { :storage => "https://localhost:6984/arctic_animal" }) 
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
run Npolar::Api::Core.new(nil, {:storage => storage, :methods => ["HEAD", "GET"]) 
```

## More topics
* [Installation](https://github.com/npolar/api.npolar.no/wiki/Install)
* [Validation](https://github.com/npolar/api.npolar.no/wiki/Validation)
* Paging
* Models
* HTTP response headers: ETag, Content-Type, Server, Date, Cache-Control
* [Attachments](https://github.com/npolar/api.npolar.no/wiki/Attachments)
* Logging
* [Performance](https://github.com/npolar/api.npolar.no/wiki/Performance)
* [Errors](https://github.com/npolar/api.npolar.no/wiki/Errors)
* [Revisions]() (edit log)
* [Formats and Media Types] (see also http://www.iana.org/assignments/media-types/index.html)