require "oai/provider"

module Metadata

  class Oai < ::OAI::Provider::Model
  
    def initialize(storage)
      @storage = storage
    end
    
    def earliest
      Date.new
    end

    def latest
      Date.new
    end

    def sets

      sets = ::Metadata::Dataset.oai_sets.map {|set|
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
      raise "Not implemented"
    end
  end

end