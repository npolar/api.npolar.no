require "npolar/api/client/json_api_client"

class Tracking < Hashie::Mash

  # Before storage lambda
  # @return [lambda]
  # See Core#handle and Core#before
  def self.before
    lambda {|request|
      if request.put? or request.post?
        Tracking.before_save(request)
      else
        request
      end
    }
  end

  # Process request before saving
  # @return request
  def self.before_save(request)

    body = request.body.respond_to?(:read) ? request.body.read : request.body.join("")

    tracks = JSON.parse(body)
    tracks = tracks.is_a?(Hash) ? [tracks] : tracks

    processed = tracks.map {|track|
      new(track).before_save(request)
    }

    body = processed.to_json
    request.body = body
    request
  end


  # Process document before saving
  # See self.before_save
  # @return [Tracking]
  def before_save(request=nil)
    self[:collection] = "tracking"
    base = URI.parse(ENV["NPOLAR_API"])
    self[:base] = base.to_s
    
    if source? and source !~ URI::REGEXP and source =~ /\w{40}/
      source = base.dup
      source.path = "/source/#{source}"
      self[:source] = source.to_s
    end

    if not edit?
      self[:edit] = "#{self[:base]}/tracking/#{id}"
    end
    if not deployment?
      
      deployment = base.dup
      
      if deployments.size == 1
        
        self[:individual] = deployments[0].individual
        self[:object] = deployments[0].object
        self[:species] = deployments[0].species
        self[:principalInvestigator] = [deployments[0].principalInvestigator]
        
        deployment.path = "/tracking/deployment/#{deployments[0][:id]}"
        self[:deployment] = deployment.to_s

      elsif deployments.size > 1

        individuals = deployments.map {|d| d.individual }.uniq
        objects = deployments.map {|d| d.object }.uniq
        specieslist = deployments.map {|d| d.species }.uniq
        
        self[:deployments] = deployments.map {|d|
          deployment.path = "/tracking/deployment/#{d.id}"
          deployment.to_s }.uniq     
        
        if individuals.size == 1
          self[:individual] = individuals[0]
        else
          self[:individuals] = individuals
        end

        if objects.size == 1
          self[:object] = objects[0]
        else
          self[:object] = "missing"
          self[:objects] = objects
        end

        if specieslist.size == 1
          self[:species] = specieslist[0]
        else
          self[:"species-list"] = specieslist
        end

      else
        self[:object] = "unknown-object"
      end
    end
    before_valid
    
    self
  end
  alias :empty :before_save

  def before_valid
    self.delete :errors
    self.delete :valid
    self
  end

  protected

  def deployment
    @@deployment ||= begin
      uri = URI.parse(ENV["NPOLAR_API_COUCHDB"])
      uri.path = "/#{Service.factory("tracking-deployment-api").database}"
      client = Npolar::Api::Client::JsonApiClient.new(uri.to_s)
    
      d = client.get_body("_all_docs", {"include_docs"=>true}).rows.map {|row|
        Hashie::Mash.new(row.doc)
      }
      d = d.reject {|d| d.deployed.nil? }
      d
    end
  end

  # @return [Array] Deployments for this platform
  def deployments

    measured = DateTime.parse(self[:measured])
    
    # From the deployment database
    deployment.select {|d|

      # Select deployment with the current platform and technology
      d.platform.to_s == platform.to_s and d.technology == technology

    }.select {|d|
  
      deployed = DateTime.parse(d.deployed)

      if d.terminated?
        # Select deployments where measured is before terminated and after deployed
        terminated = DateTime.parse(d.terminated)
        (measured >= deployed and measured <= terminated)

      else
        # No termination, select all deployments where measured is after deployed
        measured >= deployed
      end
    }
  end
end