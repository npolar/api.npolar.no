require "oai/provider"
require "date"
module Metadata
  # A dumb/unscalable CouchDB OAI-PMH provider model
  #
  # To avoid depending on views, and to get deleted documents, the provider depends
  # on CouchDB's _changes feed. However, this has no information on when the document was deleted. Oh my.
  # Likewise, to support sets and from/until queries (without views), the filtering
  # is done on the client side (meaning that all documents are retrieved first). Ouch.
  class OaiDumbCouchDbModel < ::OAI::Provider::Model

    attr_accessor :storage
    
    def self.oai_sets
      [ {:spec => "arctic", :name => "Arctic datasets"},
        {:spec => "antarctic", :name => "Antarctic datasets"},
        {:spec => "IPY", :name => "International Polar Year", :description => "Datasets from the International Polar Year (2007-2008)"},
        {:spec => "cryoclim.net", :name => "Cryoclim", :description => "Climate monitoring of the cryosphere, see http://cryoclim.net"},
        {:spec => "NMDC", :name => "Norwegian Marine Data Centre", :description => "Marine datasets"},
        {:spec => "GCMD", :name => "Global Change Master Directory" }
      ]
    end
    #arctic (191) IPY (31) GCMD (31) DOKIPY (28) NMDC (16) antarctic (8) cryoclim.net (6) gcmd (1)

    def initialize(storage)
      @storage = storage
    end
    
    def earliest
      DateTime.parse("2008-01-01T00:00:00Z").to_time.utc.xmlschema
    end

    def latest
      Date.parse("9999-12-31T23:59:59.999Z").to_time.utc.xmlschema
    end

    def timestamp_field
      "updated_time"
    end

    def sets
      sets = self.class.oai_sets.map {|set|
        OAI::Set.new(set)
      }
      sets
    end

    # find is the core method of a model, it returns records from the model
    # bases on the parameters passed in.
    #
    # <tt>selector</tt> can be a singular id, or the symbol :all
    # <tt>options</tt> is a hash of options to be used to constrain the query.
    #
    # Valid options:
    # * :from => earliest timestamp to be included in the results
    # * :until => latest timestamp to be included in the results
    # * :set => the set from which to retrieve the results
    # * :metadata_prefix => type of metadata requested (this may be useful if 
    #                       not all records are available in all formats)
    # [:all, {:metadata_prefix=>"oai_dc", :from=>-4712-01-01 00:43:00 +0043, :until=>-4712-01-01 00:43:00 +0043}]
    def find(selector, options={})
      
      if :all == selector

        storage.param = {"include_docs" => true}
        docs = JSON.parse(storage.get("_changes").body)["results"]
        
        docs = docs.map {|change|
          
          if change["deleted"] != true
            
            updated = DateTime.parse(change["doc"]["updated"]).to_time.utc.xmlschema
            dataset = Metadata::Dataset.new(change["doc"])
            dataset.sets = (dataset.sets||[]).map {|set| { spec: set } }

          else
            updated = Time.now.utc.xmlschema
            dataset = Metadata::Dataset.new({"id" => change["id"], "deleted" => true, "updated" => updated}) 
          end
          
          dataset
          
        }
       
        if options.key? :set
          docs = docs.select {|d|
            zets = (d.sets||[]).map {|s|s[:spec]}
            zets.include? options[:set]
          }
        end
        
        
        if options.key? :from
          docs = docs.select {|d|        
            updated = DateTime.parse(d["updated"]).to_time.utc
            updated >= options[:from].utc
          }
        end
        
        if options.key? :until
          docs = docs.select {|d|
            updated = DateTime.parse(d["updated"]).to_time.utc
            updated <= options[:until].utc
          }
        end

        docs
        
      else
        
        response = storage.get(selector)
        
        if 200 == response.code
          
          hash = JSON.parse(response.body)
          dataset = ::Metadata::Dataset.new(hash)
          dataset.sets = (dataset.sets||[]).map {|set|
            OAI::Set.new( {:spec => set, :name => ""})
          }
          dataset
          
        elsif 404 == response.code
          raise OAI::IdException
        else
          raise OAI::Exception.new("OAI provider crashed")
        end
      end
    end
  end

end