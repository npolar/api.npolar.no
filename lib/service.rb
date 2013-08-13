require "hashie"
require "faraday"
# Service (Service description document)
# Handles service descriptions at /service and service configuration
# Schema: http://api.npolar.no/schema/api
class Service < Hashie::Mash
  
  include Npolar::Validation::MultiJsonSchemaValidator

  def self.after_lambda
    lambda {|request, response|
      
      if response.is_a? Array and response.size == 3
        status = response[0]
      else
        response.status
      end

      if ["POST","PUT"].include? request.request_method and 201 == status
        
        service = self.new(JSON.parse(request.body.read))

        bootstrap = Npolar::Api::Bootstrap.new
        bootstrap.log = Npolar::Api.log
        bootstrap.create_database(service)

        if service.search? and service.search.engine =~ /Elasticsearch/i
          elastic = service.search
          
          status = Faraday.get("#{elastic.uri}/#{elastic["index"]}/_status").status
          if 404 == status # head does not work for status...            
            index = Faraday.put("#{elastic.uri}/#{elastic["index"]}")
            log = Npolar::Api.log
            log.info "Created Elasticsearch index #{elastic["index"]} #{index.status}: #{index.body}"
          end
          #elastic = Npolar::ElasticSearch::Client.new(request, {:uri => service.search.uri, :index => service.search["index"] })
          #elastic.create_index
        end

      end
      response
    }
  end

  def self.factory(seedfile)
    seedfile = File.absolute_path(File.join(File.dirname(__FILE__), "..", "seed", "service", seedfile))
    unless File.exists?(seedfile)
      raise "Seedfile #{seedfile} does not exist"
    end
    self.new(JSON.parse(File.read(seedfile)))
  end

  def schemas
    ["api.json"] 
  end

  def to_s
    to_json
  end

end
