require "npolar/api/client/json_api_client"
require "date"
class Tracking < Hashie::Mash

  # Before lambda for processing a request prior to storage
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

  # Process body before saving, body may contain a JSON Array
  # or 1 JSON object
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


  # Process 1 tracking document before saving
  # See self.before_save
  # @return [Tracking]
  def before_save(request=nil)
    
    self[:collection] = "tracking"
    self[:"measured-isodate"] = Date.parse(measured).iso8601
    if not warn?
      self[:warn] = []
    end

    if not base?
      baseuri = URI.parse(ENV["NPOLAR_API"])
      self[:base] = baseuri.to_s
    else
      baseuri = URI.parse(base)
    end
    
    if source? and source !~ URI::REGEXP and source =~ /\w{40}/
      sourceuri = baseuri.dup
      sourceuri.path = "/source/#{source}"
      self[:source] = sourceuri.to_s
    end

    if not edit?
      self[:edit] = "#{self[:base]}/tracking/#{id}"
    end
    
    if not program? and "argos" == "technology"
      self[:program] = "missing"
    end

    if not deployment?
      
      deploymenturi = baseuri.dup
      
      if deployments.size == 1

        # @todo only set if not present before (for all of these)  
        self[:individual] = deployments[0].individual
        self[:object] = deployments[0].object
        self[:species] = deployments[0].species
        self[:principalInvestigator] = [deployments[0].principalInvestigator]
        if principalInvestigator =~ /,/
          self[:principalInvestigator] = principalInvestigator.split(",")
        end

        deploymenturi.path = "/tracking/deployment/#{deployments[0][:id]}"
        self[:deployment] = deploymenturi.to_s
        
        begin
          DateTime.parse(deployments[0].deployed)
          self[:deployed] = deployments[0].deployed
          
        rescue
          self[:warn] << "missing-or-invalid-deployed-date" 
        end
        
        begin
          DateTime.parse(deployments[0].terminated)
          self[:terminated] = deployments[0].terminated
          
        rescue
          self[:warn] << "missing-or-invalid-terminated-date" 
        end
        

      elsif deployments.size > 1

        individuals = deployments.map {|d| d.individual }.uniq
        objects = deployments.map {|d| d.object }.uniq
        specieslist = deployments.map {|d| d.species }.uniq
        
        self[:deployments] = deployments.map {|d|
          deploymenturi.path = "/tracking/deployment/#{d.id}"
          deploymenturi.to_s }.uniq

        self[:warn] << "matches-multiple-deployments" 

        if individuals.size == 1
          self[:individual] = individuals[0]
        else
          self[:individuals] = individuals
        end

        if objects.size == 1
          self[:object] = objects[0]
        else
          self[:objects] = objects
        end

        if specieslist.size == 1
          self[:species] = specieslist[0]
        else
          self[:"species-list"] = specieslist
        end

      else
        self[:object] = "unknown"
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

  # Get all deployments from Tracking Deployment database
  def deployment
    @@deployment ||= begin
      uri = URI.parse(ENV["NPOLAR_API_COUCHDB"])
      uri.path = "/#{Service.factory("tracking-deployment-api").database}"
      client = Npolar::Api::Client::JsonApiClient.new(uri.to_s)
    
      d = client.get_body("_all_docs", {"include_docs"=>true}).rows.map {|row|
        Hashie::Mash.new(row.doc)
      }
      #d = d.reject {|depl| depl.deployed.nil? }
      d
    end
  end

  # @return [Array] Deployments for this platform, within range between
  # deployed and terminated
  def deployments

    measured = DateTime.parse(self[:measured])
    
    # From the deployment database
    deployment.select {|d|

      # Select deployment with the current platform and technology
      d.platform.to_s == platform.to_s and d.technology == technology

    }.select {|d|
  
      begin
        deployed = DateTime.parse(d.deployed)
      rescue
        deployed = DateTime.new(1000)
      end
      
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