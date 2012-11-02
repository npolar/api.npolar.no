class Gcmd::Concept < Views::Workspace

  self.template_path = File.expand_path(File.dirname(__FILE__)+"/..")
  #self.template = Views::Workspace.template

  def initialize
    @hash = { :_id => "gcmd_concept_index",
      :workspace => "gcmd",
      :summary => "Searchable GCMD Concepts as JSON/JSONP. For use in metadata editors and other systems where you might want to search and select GCMD Keywords.",
    }
  end

  def title
    "api/<a title=\"gcmd\" href=\"/gcmd\">gcmd</a>/#{workspace}"
  end

  def collections
    Gcmd::Concepts::schemas("root").map {|schema| { :title => schema, :concept => schema, :collection => schema, :href => href(schema) } }
  end

  def credits_html
    "<h4>Credits</h4>
<p>Data provided by #{link("http://gcmd.nasa.gov", "GCMD")}'s #{link("http://gcmd.gsfc.nasa.gov/Connect/", "Keyword Management System")}</p>"
  end

  def href(schema)
    "/gcmd/#{schema}"
  end

end