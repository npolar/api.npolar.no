class Gcmd::Index < Mustache

  self.template_path = File.expand_path(File.dirname(__FILE__)+"/..")

  def title
    "GCMD Concepts (JSONP service)"
  end

  def schemes
    Gcmd::Concepts::ROOT_SCHEMES.map {|scheme| { :scheme => scheme, :path => path(scheme) } }
  end

  def credits_html
    "<h4>Credits</h4>
<p>Data provided by #{link("http://gcmd.nasa.gov", "GCMD")}'s #{link("http://gcmdservices.gsfc.nasa.gov/kms/", "Keyword Management System")}</p>"
  end

  def path(scheme)
    "/gcmd?scheme=#{scheme}"
  end

  def link(href, title=nil)
    title = title.nil? ? href : title
    "<a href=\"#{href}\">#{title}</a>"
  end

  def request
    "GET #{link("/gcmd/locations?q=arctic")}"
  end

  def response
    [["d40d9651-aa19-4b2c-9764-7371bb64b9a7","ARCTIC"],["70fb5a3b-35b1-4048-a8be-56a0d865281c","ANTARCTICA"],["1ed45273-3e2b-4586-b852-05578c04041b","ARCTIC OCEAN"]].to_json
  end

end