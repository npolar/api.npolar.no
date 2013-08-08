# REST API powering http://api.npolar.no

[Rack](https://github.com/rack/rack)-based reusable building blocks for running [REST](http://en.wikipedia.org/wiki/Representational_state_transfer)-style [API](http://en.wikipedia.org/wiki/Application_programming_interface)s.
over [HTTP](http://www.w3.org/Protocols/rfc2616/rfc2616.html).

## Document API

Examples for [/dataset](http://api.npolar.no/dataset/) API (discovery level metadata about a dataset)
* http://api.npolar.no/dataset/025b82e5-4a5a-558f-b021-17c1a60f0922.json
* http://api.npolar.no/dataset/025b82e5-4a5a-558f-b021-17c1a60f0922.dif
* http://api.npolar.no/dataset/025b82e5-4a5a-558f-b021-17c1a60f0922.iso

### GET (Accept)
```json
$ curl -X GET http://api.npolar.no/dataset/025b82e5-4a5a-558f-b021-17c1a60f0922 -H "Accept: application/json"```
$ curl -X GET http://api.npolar.no/dataset/025b82e5-4a5a-558f-b021-17c1a60f0922 -H "Accept: application/xml"
$ curl -X GET http://api.npolar.no/dataset/025b82e5-4a5a-558f-b021-17c1a60f0922 -H "Accept: application/atom+xml"
```


### HEAD
```json
$ curl -iX HEAD  http://api.npolar.no/dataset/025b82e5-4a5a-558f-b021-17c1a60f0922
```

### POST
```json
$ curl -niX POST https://api.npolar.no/dataset -d@/path/dataset.json -H "Content-Type: application/json"
```

### PUT
```json
$ curl -niXPUT  https://api.npolar.no/dataset/025b82e5-4a5a-558f-b021-17c1a60f0922 -d@/path/dataset-.json -H "Content-Type: application/json" 
```

### Multiple documents
Publishing multiple DIF XML, wrapped in OAI-PMH

```json
$ curl -niX POST  https://api.npolar.no/dataset-d@seed/dataset/ris-dif.xml -H "Content-Type: application/xml"
```

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
* [Formats and Media Types](https://github.com/npolar/api.npolar.no/wiki/Formats) (see also http://www.iana.org/assignments/media-types/index.html)

## Documentation and quality efforts
[![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/npolar/api.npolar.no)
* http://rdoc.info/github/npolar/api.npolar.no
