# REST API lego kit powering http://api.npolar.no

[Rack](https://github.com/rack/rack)-based reusable building blocks for running [REST](http://en.wikipedia.org/wiki/Representational_state_transfer)-style [API](http://en.wikipedia.org/wiki/Application_programming_interface)s
over [HTTP](http://www.w3.org/Protocols/rfc2616/rfc2616.html).

API endpoints are constructed like [lego](http://lego.dk) blocks by connecting a minimalist [Core](https://github.com/npolar/api.npolar.no/wiki/Core) instance with a [Storage](https://github.com/npolar/api.npolar.no/wiki/Storage) object and assembling
other middleware for security, validation, search/indexing, logging, transformation, etc.


## Features
* Storage neutral, but currently built around CouchDB
* Lucene-based search via Elasticsearch or Solr
* Authorization
* Edit log
* JSON schema (validation)
* GeoJSON
* API browser, see e.g. http://api.npolar.no/dataset/?q=
* Model hooks
* Self-describing, see. http://api.npolar.no/service/dataset-api

## Getting started
* [Installation](https://github.com/npolar/api.npolar.no/wiki/Install)
* How to publish a [new API](https://github.com/npolar/api.npolar.no/wiki/New-API)

[![Code Climate](https://codeclimate.com/github/npolar/api.npolar.no.png)](https://codeclimate.com/github/npolar/api.npolar.no)
[RubyDoc](http://rdoc.info/github/npolar/api.npolar.no/index)
