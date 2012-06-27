### Create endpoint
#### Path
``` ruby
# config.ru
map "/link" do
  run Api::Endpoint.app
end
```
`GET` http://localhost:9393/link/ will now provide you with a nice [503] error

#### Security
``` ruby
  
```

#### Storage
``` ruby
# config.ru
map "/link" do
  storage = Api::Storage::Couch.new("http://localhost:5984/api_collection1")
  run Api::Endpoint.app({:storage => storage)
end
```


#### Formats

Use :formats to set available response formats.
Use :accepts to set which formats the endpoint will accept in the POST/PUT body

``` ruby
  run Api::Endpoint.app({:storage => storage, :formats=>["json","xml"], :accepts => ["json", "xml"]})
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
  run Api::Endpoint.app({:storage => storage, :formats=>["atom", "dif", "iso", "json", "xml"]})
end
```
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
  run Api::Endpoint.app, {:storage => storage, :methods => ["HEAD", "GET"], :formats => ["json"]} 
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
