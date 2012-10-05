# encoding: utf-8
module Views
  class Collection < Npolar::Mustache::JsonView

    def initialize(model=nil)  
      @hash = { :_id => "collection_show",
      }
      
    end

    def accepts
      { :accept => "json"}
    end

    # Override
    def id(collection=nil)
      "id"
    end

    def format(collection=nil)
      "json"
    end
  
    def collections
      collections = ::Metadata.collections.sort.map {|c|
        {
          :id => id,
          :title => c.capitalize,
          :collection => c,
          :href => "/#{::Metadata.workspace}/#{c}",
          :list_formats => static(c, :list_formats),
          :example_href => static(c, :uri)+"/"+static(c, :example_id),
          :summary => static(c, :summary),
          :formats => static(c, :formats).map {|f| { :format => f } },
          :accepts => static(c, :accepts).map {|a| { :accept => a, :schema_uri => static(c, :schema_uri, a) } }
        }
      }
    end

    def title
      ""
    end
  
    protected
  
    def static(collection, method, *args)
      case collection
        when "dataset" then ::Metadata::Dataset.send(method, *args)
        else ""
      end
    end
  
    def model(collection)
      raise "Implement in subclass"
    end
  
  end
end