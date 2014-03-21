# encoding: utf-8
require "hashie"
require "date"
require "time"

module Monitoring

  # [Npolar timeseries](http://api.npolar.no/schema/timeseries) model
  #
  # [License]
  #   {http://www.gnu.org/licenses/gpl.html GNU General Public License Version 3} (GPLv3)
  #
  # @author Conrad Helgeland
  class Timeseries < Hashie::Mash

    #include Npolar::Validation::MultiJsonSchemaValidator
    
    BASE = "http://api.npolar.no/monitoring/timeseries"

    # JSON_SCHEMA_URI = "http://api.npolar.no/schema/timeseries"

    # JSON_SCHEMAS = ["timeseries.json"]

    class << self
      attr_accessor :base
    end

    # After-request response processor
    # @return lambda yielding [Rack::Response]
    # See Core#handle and Core#after
    def self.after
      lambda {|request,response|
        if request.get?
          after_get(request,response)
        else
          response
        end
      }
    end

    # CSV response
    def self.after_get(request,response)
      if request.id =~ /^\w{26,}$/
        body = response.body.join("") # FIXME - why is body Array!?
        hash = JSON.parse(body)
        if request.format =~ /^json$/
          hash["_links"] = hash["links"]
          hash["_links"]["self"] = { href: hash["_links"]["edit"]["href"].gsub(/^https/, "http") }
          hash.delete("links")
          response.body = StringIO.new(hash.to_json)
          response
        elsif request.format =~ /^csv|tsv$/       
        response.body = StringIO.new(CSV.generate do |csv|
          csv << hash["units"]                                       
          hash["data"].each do |row|
            csv << row
          end
        end)
        response
      else
        response
      end
      
      else
        response
      end
      
    end

    # Before request processor
    # @return lambda yielding [Rack::Request]
    # See Core#handle and Core#before
    #def self.before
    #  lambda {|request|
    #    if request.put? or request.post?
    #      before_save(request)
    #    else
    #      request
    #    end
    #  }
    #end
    
    # Default licences
    def self.licences
      ["http://data.norge.no/nlod/no/1.0",
      "http://creativecommons.org/licenses/by/3.0/no/"]
    end

    # Before save: Add information to timeserie
    # See self.before_save
    # @todo Set arctic/antarctic based on coverage.latitude !?
    #def before_save(request=nil)
    #
    #    self[:collection] = "timeseries"
    #
    #  
    #    if not title?
    #      self[:title] = "Monitoring timeseries created by #{username} at #{Time.now.utc.iso8601}"
    #    end
    #
    #    if not licences? or licences.none?
    #      self[:licences] = self.class.licences
    #    end
    #
    #    if not topics? or topics.none?
    #      self[:topics] = ["other"]
    #    end
    #
    #    if not schema?
    #      self[:schema] = self.class.schema_uri
    #    end        
    #
    #    self
    #end
    #alias :empty :before_save

    # Manipulates timeserie before validation
    # @override MultiJsonSchemaValidator
    # @return self
    #def before_valid
    #  self
    #end

    def to_solr
      
      solr = self.reject {|k,v| k=~ /^links|data|title|label/ }.merge({
        title: title.en,
        "indicator" => self[:links][:"indicator"][:href],
        "parameter" => self[:links][:"parameter"][:href],
        "indicator-title" => self[:"indicator-title"][:en],
        "parameter-title" => self[:"parameter-title"][:en]
      })
    end

    # @override MultiJsonSchemaValidator
    def schemas
      JSON_SCHEMAS
    end
    
  end
  
end