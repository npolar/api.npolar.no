# api.npolar.no

* Searchable document storage service
* RESTful HTTP API
* Powered by Ruby, CouchDB, and Apache Solr

# Use
``` ruby
# config.ru
map "/my/api/collection" do

  server = Api::Server.new

  storage = Api::Storage::Couch.new({"read" => "http://localhost:5984/my_api_collection/")

  server.collection = Api::Collection.new(storage)

  run server

end
```

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

## Install
-------
$ git clone git@github.com:npolar/api.npolar.no.git 
$ cd api.npolar.no
$ bundle install
$ rspec
$ bundle exec shotgun -d

For production, we use unicorn + nginx

## Similar projects
* GRAPE
* https://github.com/olivernn/rackjson
* https://github.com/fnando/rack-api