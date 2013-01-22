# 

# JSON feed writer for the "api" Solr core, see
class Npolar::Api::SolrQuery

  def self.q(request)
    qstar = request["q"] ||= "*"
   
    if qstar =~ /^[^\*]+:.+$/ 
      # remove any whitespace around :
      qstar = qstar.sub(/\s*:\s*/, ':')

      # ensure 'TO' doesn't appear in any other case
      qstar = qstar.sub(/to/i, 'TO')
    elsif qstar =~ /^[\*]$|^\*\:\*$|^(\s+)?$/
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
