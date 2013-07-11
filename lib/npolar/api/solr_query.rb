class Npolar::Api::SolrQuery

  def self.q(request)
    qstar = request["q"].downcase ||= "*"
    
    if qstar =~ /^[\*]$|^\*\:\*$|^(\s+)?$/
      qstar = "*:*"
    else
      qstar = "title:'#{qstar}' OR '#{qstar}' OR '#{qstar}*'"
    end
    qstar
  end

  def self.fields
    ["self", "id", "latitude", "longitude", "title", "collection", "size", "parameter", "category", "link_*"]       
  end
  
  def self.dates
    ["edited", "published", "created", "updated", "modified", "measured", "datetime", "datestamp"]
  end

  def self.rows
    10
  end

end