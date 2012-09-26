require "oai/provider"

module Metadata
  class OaiRepository < ::OAI::Provider::Base

    @@storage = nil
    # http://www.openarchives.org/OAI/2.0/oai-identifier.xsd#repositoryIdentifierType
    # [a-zA-Z][a-zA-Z0-9\-]*(\.[a-zA-Z][a-zA-Z0-9\-]*)+

    def self.storage
      @@storage
    end

    def self.storage=storage
      @@storage=storage
    end

    repository_name ::Metadata::Dataset.title
    repository_url  "http://api.npolar.no/metadata/oai"
    record_prefix "oai:npolar.no"
    admin_email ["data@npolar.no"]
    source_model Oai.new(storage)
    extra_description ::Metadata::Dataset.summary
  end
end