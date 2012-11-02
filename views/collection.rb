# encoding: utf-8
module Views
  class Collection < Npolar::Mustache::JsonView

    def h1_title
      "<span id=\"title\"><a href=\"/\">api</a>/<a title=\"#{workspace}\" href=\"/#{workspace}\">#{workspace}</a>/#{collection}</span>"
    end
  
    def format
      if respond_to? :formats
        if formats.first.key? :format
          formats.first[:format]
        else
          formats.first
        end
      end
    end

    def example_edit_href
      "#{href}/#{example_id}.#{format}"
    end

    def verbs
      if @hash.key? :methods
        @hash[:methods].map {|v| {:verb => v} }
      end
    end

    def parameters
      unless @hash.key? :parameters
      @hash[:parameters] = []
        if @hash.key? :searchable and @hash[:searchable]
          @hash[:parameters] = ["q", "limit", "facets", "filters"]
        end
        # revisions
      end
      @hash[:parameters].map {|p| {:parameter => p} }
    end

  end
end