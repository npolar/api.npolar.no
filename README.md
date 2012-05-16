Source code for http://api.npolar.no

* Searchable document storage service
* RESTful HTTP API
* Powered by Ruby, CouchDB, Git, Linux, Apache Solr

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
* Choose your own storage servers
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
* Aims 100% test coverage

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
