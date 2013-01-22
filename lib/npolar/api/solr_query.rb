# 

# JSON feed writer for the "api" Solr core, see
class Npolar::Api::SolrQuery

  def self.q(request)
    qstar = request["q"] ||= "*"
   
    if not qstar =~ /^[^\*]+:.+$/ 
      if qstar =~ /^[\*]$|^\*\:\*$|^(\s+)?$/
        qstar = "*:*"
      else
        #unless qstar =~ /\*/
        #  qstar = qstar.downcase #+"*"
        #end
        qstar = "title:#{qstar} OR #{qstar} OR #{qstar}*"
      end
    end
    qstar
  end
end
