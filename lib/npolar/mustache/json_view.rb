# encoding: utf-8
class Npolar::Mustache::JsonView < ::Mustache

  self.template_path = File.expand_path(File.dirname(__FILE__)+"/../../../views")

  self.view_namespace = ::Views
  
  attr_accessor :storage, :hash, :head, :foot, :id

  def call(env)
    request = Npolar::Rack::Request.new(env)
    if "json" === request.format
      json = respond_to?(:data) ? data.to_json : get(id).to_json

      [200, {"Content-Type" => "application/json"},[json]]
    else
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
  <title>{{title}}</title>
  <meta charset="utf-8">
  <link href="/favicon.ico" rel="shortcut icon" type="image/x-icon">
  <link href="http://twitter.github.com/bootstrap/assets/css/bootstrap.css" rel="stylesheet">
  <link href="http://twitter.github.com/bootstrap/assets/css/bootstrap-responsive.css" rel="stylesheet">
</head>
<body class="container-fluid">

  <header><h1>{{title}}</h1></header>
 
      eos
    end
  end

  def foot
    if get(id).include? :foot
      get(id)[:foot]
    else
      "</body></html>"
    end
  end

  def initialize(hash = {})
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

end