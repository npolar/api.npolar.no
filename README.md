# REST API lehgo kit powering http://api.npolar.no

[Rack](https://github.com/rack/rack)-based reusable building blocks for running [REST](http://en.wikipedia.org/wiki/Representational_state_transfer)-style [API](http://en.wikipedia.org/wiki/Application_programming_interface)s
over [HTTP](http://www.w3.org/Protocols/rfc2616/rfc2616.html).

API endpoints are constructed like [lego](http://lego.dk) blocks by connecting a minimalist [Npolar::Api::Core](https://github.com/npolar/api.npolar.no/wiki/Core) instance with a [Storage](https://github.com/npolar/api.npolar.no/wiki/Storage) object and assembling
other[middleware for security, validation, search/indexing, logging, transformation, etc.

* [Installation](https://github.com/npolar/api.npolar.no/wiki/Install)
* How to publish a [new API](https://github.com/npolar/api.npolar.no/wiki/New-API)

https://codeclimate.com/github/npolar/api.npolar.no [![Code Climate](https://codeclimate.com/github/npolar/api.npolar.no.png)](https://codeclimate.com/github/npolar/api.npolar.no)

http://rdoc.info/github/npolar/api.npolar.no
