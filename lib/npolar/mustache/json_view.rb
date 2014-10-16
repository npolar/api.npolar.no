# encoding: utf-8

# JSON feed => Mustache object
class Npolar::Mustache::JsonView < ::Mustache

  self.template_path = File.expand_path(File.dirname(__FILE__)+"/../../../views")

  self.view_namespace = ::Views
  
  attr_accessor :app, :storage, :hash, :head, :foot, :id

  def call(env)
    request = Npolar::Rack::Request.new(env)
        
    if "json" == request.format
      if request["q"].nil? 
        json = respond_to?(:data) ? data.to_json : get(id).to_json
        [200, {"Content-Type" => "application/json"},[json]]
      else
        @app.call(env)
      end
    
    elsif "html" == request.format and request["q"].nil? and request.path_info != "/" and not @app.nil?
      @app.call(env)

    # Feed only HTML middleware, ie. path info needs to be /
    else
      unless (request["q"].nil?) or @app.nil?
        status, headers, body = @app.call(env)

        if 200 == status and headers["Content-Type"] =~ /application\/json/

          if body.respond_to?(:body)
            jtext = body.body.join 
          else
            jtext = body.join
          end
     
          feed = Hashie::Mash.new(Yajl::Parser.parse(jtext, {:symbolize_keys => true}))

          if feed.key? :feed
            @hash[:feed] = feed[:feed]
          else
            raise "No feed returned" 
          end
        end
      end
      [200, {"Content-Type" => "text/html"},[render]]
    end
  end

  def head
    if get(id).include? :head
      get(id)[:head]
    else
      @head ||= render <<-eos
<!DOCTYPE html>
<html lang="en">
<head>
  <title>{{head_title}}</title>
  <meta charset="utf-8" />
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
  <meta name="viewport" content="width=1024, user-scalable=no">
    
  <link href="/favicon.ico" rel="shortcut icon" type="image/x-icon" />
  <!-- Boostrap 2 needed for wide right hand facet column -->
  <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/css/bootstrap-combined.min.css" rel="stylesheet">
  
  <link rel="stylesheet" href="//maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css">

  <link rel="stylesheet" href="//maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap-theme.min.css">

  <script src="//ajax.googleapis.com/ajax/libs/jquery/2.1.1/jquery.min.js"></script>
  <script src="//maxcdn.bootstrapcdn.com/bootstrap/3.2.0/js/bootstrap.min.js"></script>
      
    <style>
      html { height: 100% }
      body { height: 100%; margin: 0; padding: 0;}
      #map{ height: 100% }
    </style>
    
    <link rel="stylesheet" href="//cdn.leafletjs.com/leaflet-0.7.3/leaflet.css" />
    <script src="//cdn.leafletjs.com/leaflet-0.7.3/leaflet.js"></script>
    <script type="text/javascript" src="/js/leaflet.ajax.min.js"></script>

  {{{ head_links }}}
</head>
<body class="container-fluid">

  

      eos
    end
  end

  def foot
    if get(id).include? :foot
      get(id)[:foot]
    else
    
    
      "<script src=\"//netdna.bootstrapcdn.com/bootstrap/3.1.1/js/bootstrap.min.js\"></script>

</body></html>"
    end
  end

  def initialize(attr = {})
    @hash = hash
  end

  # Handles Mustache methods
  # E.g. {{ title}} => [:title, [], nil]
  def method_missing(method_symbol, *arguments, &block) 
    hash = @hash ||= get(id)
    if hash.include? method_symbol
      hash[method_symbol]
    else
      super
    end
  end

  def head_title
    if respond_to? :title
      title
    else
      ""
    end
  end

  def respond_to?(method_symbol, include_private = false)
    if get(id).include? method_symbol
      true
    else
      super
    end
  end

  protected

  def get(id)

    @hash ||= begin

      status, headers, str = storage.get(id)

      if 200 == status
        y = Yajl::Parser.new(:symbolize_keys => true)
        @hash = y.parse(str)
        @hash
      else
        {}
      end
    end
    

  end

  def link(href, title=nil)
    title = title.nil? ? href : title
    "<a href=\"#{href}\">#{title}</a>"
  end

end