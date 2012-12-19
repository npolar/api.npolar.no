# 

# JSON feed writer for the "api" Solr core, see
class Npolar::Api::SolrQuery

  def self.q(request)
    qstar = request["q"] ||= "*"
    
    if qstar =~ /^[\*]$|^\*\:\*$|^(\s+)?$/
      qstar = "*:*"
    else
      #unless qstar =~ /\*/
      #  qstar = qstar.downcase #+"*"
      #end
      qstar = "title:#{qstar} OR #{qstar} OR #{qstar}*"
      end
    qstar
  end
end