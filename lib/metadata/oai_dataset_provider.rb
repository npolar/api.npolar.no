require "oai/provider"

#module OAI::Provider::Response
#  class RecordResponse
#    # Monkey patch #timestamp_for because it expects the timestamp_field to r
#    # /home/ch/github.com/ruby-oai/lib/oai/provider/response/record_response.rb
#    def timestamp_for(record)
#      record.send(provider.model.timestamp_field)
#    end
#  end
#end

module Metadata
  class OaiDatasetProvider < ::OAI::Provider::Base

    class << self
      client = Npolar::Api::Client::JsonApiClient.new(ENV["NPOLAR_API_COUCHDB"].gsub(/[\/]$/, "")+"/dataset")
      client.model = ::Metadata::Dataset.new
      @@client=client
    end
    
    # http://www.openarchives.org/OAI/2.0/oai-identifier.xsd#repositoryIdentifierType
    # /[a-zA-Z][a-zA-Z0-9\-]*(\.[a-zA-Z][a-zA-Z0-9\-]*)+/
    # @todo declare "deleted records" support (how?)

    register_format ::Metadata::OaiDirectoryInterchangeFormat.instance
    repository_name  "Norwegian Polar Institute's OAI-PMH service for dataset metadata"
    repository_url  "#{ENV["NPOLAR_API"].gsub(/^https/, "http")}/dataset/oai"
    record_prefix "oai:npolar.no:dataset"
    admin_email "data@npolar.no"
    source_model ::Metadata::OaiDumbCouchDbModel.new(@@client)
    extra_description  "Norwegian Polar Institute's datasets (from 2008 to present).
      See also http://api.npolar.no/dataset/?q= and http://data.npolar.no/datasets for more information"
    sample_id "3925805c-3ab1-44bd-99bb-a0b26321953f"
    
  end
end