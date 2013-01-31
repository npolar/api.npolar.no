# JSON feed writer for the "api" Solr core
class Npolar::Api::SolrQuery

  attr_writer :request

  def request
    if @request.nil?
      raise ArgumentError "Rack::Request instance missing"
    end
    @request
  end

  def self.q(request)
    qstar = request["q"] ||= "*"
   
    if qstar =~ /^[^\*]+:.+$/ 
      # remove any whitespace around :
      qstar = qstar.gsub(/\s*:\s*/, ':')

      # ensure 'TO' doesn't appear in any other case
      qstar = qstar.gsub(/to/i, 'TO')
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

  def ranges(range_marker=/\.\./)
    request.params.select {|k,v| v =~ range_marker }
  end

  # @param range start..end
  # @return string "field:[start TO end]"
  def fq_range(field, from, to)
    "#{field}:[#{from} TO #{to}]"
  end

end
