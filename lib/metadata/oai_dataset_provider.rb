require "oai/provider"

module Metadata
  class OaiDatasetProvider < ::OAI::Provider::Base

    def self.topic_sets
      ["glaciology", "marine"]
    end

    def self.oai_sets
      sets = [ {:spec => "arctic", :name => "Arctic datasets"},
        {:spec => "antarctic", :name => "Antarctic datasets"},
        {:spec => "ipy.org", :name => "International Polar Year", :description => "Datasets from the International Polar Year (2007-2008), see http://www.ipy.org"},
        {:spec => "cryoclim.net", :name => "Cryoclim", :description => "Climate monitoring of the cryosphere, see http://cryoclim.net"},
        {:spec => "gcmd.nasa.gov", :name => "Global Change Master Directory" },
        {:spec => "N-ICE2015", :name => "N-ICE2015 datasets" }
      ]+self.topic_sets.map {|t| { spec: t, name: t.capitalize+" datasets", description: "See http://api.npolar.no/dataset/?q=&filter-topics=#{t}" } }
      sets
    end
    
    def self.sets
      topic_sets + oai_sets.map {|os| os[:spec]}
    end
    
    class << self
      
      uri = URI.parse(ENV["NPOLAR_API_COUCHDB"]||"http://localhost:5984")
      uri.path = "/dataset"
      
      client = Npolar::Api::Client::JsonApiClient.new(uri.to_s)
      client.model = ::Metadata::Dataset.new
      @@client=client
    end
    
    # http://www.openarchives.org/OAI/2.0/oai-identifier.xsd#repositoryIdentifierType
    # /[a-zA-Z][a-zA-Z0-9\-]*(\.[a-zA-Z][a-zA-Z0-9\-]*)+/

    register_format ::Metadata::OaiDirectoryInterchangeFormat.instance
    repository_name  "Norwegian Polar Institute's OAI provider for dataset metadata"
    repository_url  "#{ENV["NPOLAR_API"]||''.gsub(/^https/, "http")}/dataset/oai"
    record_prefix "oai:npolar.no:dataset"
    admin_email "data@npolar.no"
    source_model ::Metadata::OaiDumbCouchDbModel.new(@@client)
    extra_description  "OAI-PMH provider for Norwegian Polar Institute's datasets as DIF XML
    
      See http://api.npolar.no/dataset/?q= for a searchable Dataset API that delivers 
      metadata of datasets in JSON, CSV, DIF, or ISO 19000 formats.
      
      See also: http://data.npolar.no/datasets
      
      For DIF XML, see: http://gcmd.gsfc.nasa.gov/add/difguide/index.html
    
      http://api.npolar.no/dataset/oai supports all 6 verbs from v2 spec http://www.openarchives.org/OAI/openarchivesprotocol.html#ProtocolMessages
        * http://api.npolar.no/dataset/oai?verb=Identify
        * http://api.npolar.no/dataset/oai?verb=ListIdentifiers
        * http://api.npolar.no/dataset/oai?verb=ListMetadataFormats
        * http://api.npolar.no/dataset/oai?verb=ListSets [currently:#{self.sets.to_json}]
        * http://api.npolar.no/dataset/oai?verb=GetRecord&amp;metadataPrefix=dif&amp;identifier=0323b588-5023-57d1-bf98-201cd8192730
        * http://api.npolar.no/dataset/oai?verb=ListRecords&amp;metadataPrefix=dif
      
      Sets
        * http://api.npolar.no/dataset/oai?verb=ListIdentifiers&amp;metadataPrefix=dif&amp;set=cryoclim.net
      Time range
        * http://api.npolar.no/dataset/oai?verb=ListIdentifiers&amp;from=2013-11-01&amp;until=2013-11-15&amp;metadataPrefix=dif
      Time range and sets
        * http://api.npolar.no/dataset/oai?verb=ListIdentifiers&amp;from=2013-11-01&amp;until=2099-01-01&amp;metadataPrefix=dif&amp;set=cryoclim.net
    "
    sample_id "3925805c-3ab1-44bd-99bb-a0b26321953f"
    deletion_support OAI::Const::Delete::PERSISTENT
    update_granularity OAI::Const::Granularity::HIGH
 
  end
end
