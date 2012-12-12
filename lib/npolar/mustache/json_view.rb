# encoding: utf-8
class Npolar::Mustache::JsonView < ::Mustache

  self.template_path = File.expand_path(File.dirname(__FILE__)+"/../../../views")

  self.view_namespace = ::Views
  
  attr_accessor :app, :storage, :hash, :head, :foot, :id

  def call(env)
    request = Npolar::Rack::Request.new(env)
        
    if "json" === request.format
      if request["q"].nil?
        json = respond_to?(:data) ? data.to_json : get(id).to_json
        [200, {"Content-Type" => "application/json"},[json]]
      else
        @app.call(env)
      end
    else
      unless (request["q"].nil?) or @app.nil?
        status, headers, body = @app.call(env)
        if 200 == status and headers["Content-Type"] =~ /application\/json/
          feed = Yajl::Parser.parse(body.join, {:symbolize_keys => true})
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
  <link href="/favicon.ico" rel="shortcut icon" type="image/x-icon" />
  <link href="http://twitter.github.com/bootstrap/assets/css/bootstrap.css" rel="stylesheet" />
  <link href="http://twitter.github.com/bootstrap/assets/css/bootstrap-responsive.css" rel="stylesheet" />  
  {{{head_links}}}
</head>
<body class="container-fluid">

  

      eos
    end
  end

  def foot
    if get(id).include? :foot
      get(id)[:foot]
    else
      "<script src=\"http://code.jquery.com/jquery-latest.js\"></script>
<script src=\"http://twitter.github.com/bootstrap/assets/js/bootstrap-dropdown.js\"></script> 
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