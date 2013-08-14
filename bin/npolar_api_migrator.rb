#!/usr/bin/env ruby

# ./bin/npolar_api_migrator.rb http://api:9393/dataset ::Metadata::Dataset ::Metadata::DatasetMigration0

require "bundler/setup"
require "yajl/json_gem"
require "logger"
require_relative "./../lib/npolar/http"
require_relative "./../lib/npolar/api/client"
require_relative "./../lib/npolar/validation/multi_json_schema_validator"
require_relative "./../lib/metadata/dataset"
require_relative "./../lib/metadata/dataset_migration0"
require_relative "./../lib/service"
require_relative "./../lib/npolar/factory"
require_relative "./../lib/npolar/api/migrator"

module Npolar

  begin
  
    unless 3 == ARGV.size
      raise ArgumentError, "Usage: \ #{__FILE__} {URI} {Model} {Migration}"
    end
    
    uri = ARGV[0].gsub(/\/$/, "")
    modelclass = ARGV[1]
    migratorclass = ARGV[2]
  
    client = Api::Client.new(uri)
    client.model = Factory.constantize(modelclass).new

    log = client.log
    batch = `uuidgen`.chomp
    number = 0
    log = ::Logger.new(STDERR)
    log.level = Logger::INFO


    log.info "Running #{File.absolute_path(__FILE__)} batch #{batch} using #{migratorclass}"
    migrator = Api::Migrator.new
    migrator.log = log
    migrator.uri = uri
    migrator.client = client
    migrator.migrations = Factory.constantize(migratorclass).new.migrations
    migrator.batch = batch
    migrator.run

    exit(0)
  
  rescue => e
    raise e
    exit(1)
  end 

end