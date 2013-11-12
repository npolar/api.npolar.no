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
  def before_save(request=nil)

    if not individual?
      if deployments.size == 1
    
        self[:individual] = deployments[0].individual
        self[:object] = deployments[0].object
        self[:species] = deployments[0].species
        self[:deployment] = deployments[0][:id]

      elsif deployments.size > 1

        individuals = deployments.map {|d| d.individual }.uniq
        objects = deployments.map {|d| d.object }.uniq
        specieslist = deployments.map {|d| d.species }.uniq
        
        
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
      client = Npolar::Api::Client.new("http://api.npolar.no/tracking/deployment")
      client.model = Hashie::Mash.new
      client.all.reject {|d| d.individual.nil? or d.deployed.nil? }
    end
  end

  def deployments
    measured = DateTime.parse(self[:measured])
    deployment.select {|d|

      d.platform.to_s == platform.to_s

    }.select {|d|

      deployed = DateTime.parse(d.deployed)

      if d.terminated?
        terminated = DateTime.parse(d.terminated)

        (measured >= deployed and measured <= terminated)

      else 
        measured >= deployed
      end
    }
  end
end