require "oai/provider"

module Metadata
  class OaiRepository < ::OAI::Provider::Base

    # http://www.openarchives.org/OAI/2.0/oai-identifier.xsd#repositoryIdentifierType
    # /[a-zA-Z][a-zA-Z0-9\-]*(\.[a-zA-Z][a-zA-Z0-9\-]*)+/

    #register_format ::Metadata::DirectoryInterchangeFormat.instance
    #repository_name ::Metadata::Dataset.title
    #repository_url  "http://api.npolar.no"+::Metadata::Dataset::BASE+"/oai"
    #record_prefix "oai:npolar.no"
    #admin_email ["data@npolar.no"]
    #
    #source_model ::Metadata::Oai.new(Npolar::Storage::Couch.new(ENV["NPOLAR_API_COUCHDB"].gsub(/[\/]$/, "")+"/metadata_dataset"))
    #extra_description ::Metadata::Dataset.summary
    #sample_id "3925805c-3ab1-44bd-99bb-a0b26321953f"
  end
end