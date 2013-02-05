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
    query = request["q"]
    if query.nil? || query.empty?
      return "*"
    end
   
    ranges = self.ranges(request["q"])
       
    if !ranges.empty? 
      ranges = ranges.map { |range| self.fq_range(range[0], range[1], range[2]) }
      query = ranges.join(" AND ")

    elsif query =~ /^[^\*]+:.+$/ 
      # remove any whitespace around :
      query = query.gsub(/\s*:\s*/, ':')

      # ensure 'TO' doesn't appear in any other case
      query = query.gsub(/to/i, 'TO')

    elsif query =~ /^[\*]$|^\*\:\*$|^(\s+)?$/
        query = "*:*"

    else
        #unless query =~ /\*/
        #  query = query.downcase #+"*"
        #end
      query = "title:#{query} OR #{query} OR #{query}*"
    end

    return query
  end

  def self.ranges(query)
    query.scan(/\s*(\w+)=([0-9\-])?\.\.([0-9\-])?\s*/)
  end

  # @param range start..end
  # @return string "field:[start TO end]"
  def self.fq_range(field, from, to)
    from ||= "*"
    to ||= "*"
    "#{field}:[#{from} TO #{to}]"
  end

end
