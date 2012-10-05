# encoding: utf-8
module Views
  class Workspace < Npolar::Mustache::JsonView

    def initialize  
      @hash = { :_id => "workspace_index",
        :title => "Workspace",
        :workspace => "uknown",
        :summary => "Unknown workspace",
        :data => { "workspace" => ::Metadata.workspace, "collections" => collections.map {|c|c[:href]} } 
      }
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
      "<a title=\"api.npolar.no\" href=\"/\">api</span></a>/#{workspace}"
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