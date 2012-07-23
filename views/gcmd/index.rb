class Gcmd::Index < Mustache

  self.template_path = File.expand_path(File.dirname(__FILE__)+"/..")

  def title
    "GCMD Concepts (JSONP service)"
  end

  def schemes
    Gcmd::Concepts::ROOT_SCHEMES.map {|scheme| { :scheme => scheme, :path => path(scheme) } }
  end

  def credits
    "GCMD credit"
  end

  def path(scheme)
    "/gcmd/#{scheme}"
  end

end