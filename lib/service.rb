require "hashie"
require "faraday"

# Service
# Model for /service API
# Schema: http://api.npolar.no/schema/api
class Service < Hashie::Mash

  include Npolar::Validation::MultiJsonSchemaValidator

  # On POST, PUT Service:
  # * create CouchDB database
  # * create Elasticsearch index, mapping, and CouchDB river
  def self.after_lambda
    lambda {|request, response|
      response
    }
  end

  # def self.after_lambda
  #   lambda {|request, response|
  #
  #     if response.is_a? Array and response.size == 3
  #       status = response[0]
  #     else
  #       status = response.status
  #     end
  #
  #     if ["POST","PUT"].include? request.request_method and 201 == status
  #
  #       service = self.new(JSON.parse(request.body.read))
  #
  #       bootstrap = Npolar::Api::Bootstrap.new
  #       bootstrap.log = Npolar::Api.log
  #       bootstrap.bootstrap(service, false) # false => don't inject the service document we just created
  #     end
  #     response
  #   }
  # end

  def self.factory(seedfile)
    seedfile = File.absolute_path(File.join(File.dirname(__FILE__), "..", "seed", "service", seedfile))
    unless File.exists?(seedfile)
      seedfile += ".json"
    end
    unless File.exists?(seedfile)
      raise "Seedfile #{seedfile} does not exist"
    end
    self.new(JSON.parse(File.read(seedfile)))
  end

  def schemas
    ["api.json"]
  end

  # Get all services
  # @todo Dynamic method depending on service database
  def self.services(database=nil, select=nil)
    if database.nil?
      database = Service.factory("service-api").database
    end

    client = Npolar::Api::Client::JsonApiClient.new(ENV["NPOLAR_API_COUCHDB"]+"/#{database}")
    client.get_body("_all_docs", {"include_docs"=>true}).rows.map {|row|
      Service.new(row.doc)
    }
  end

  def to_s
    to_json
  end

end
