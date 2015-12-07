require "npolar/api/client/json_api_client"
require "argos"
require "date"

class Tracking < Hashie::Mash

  include Argos::SensorData
  
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

  # Process body before saving
  # Body may contain a JSON Array or 1 JSON object
  # @return request
  def self.before_save(request)

    body = request.body.respond_to?(:read) ? request.body.read : request.body.join("")

    tracks = JSON.parse(body)

    
    tracks = tracks.is_a?(Hash) ? [tracks] : tracks

    processed = tracks.map {|track|
      new(track).before_save(request)
    }
    if request.request_method == "PUT"
      processed = processed.first
    end
    body = processed.to_json
    
    request.body = body
    request
  end

  # Add platform/deployment metadata and decode sensor data befor saving
  # @return [Tracking]
  def before_save(request=nil)
    
    self[:collection] = "tracking"
    # @todo self schema ==> current schema
    
    if not warn?
      self[:warn] = []
    end

    # Base URI, used to set source and deployment URIs
    if not base?
      self[:base] = base_uri
    end
    
    # Set source to URI if it's a SHA1 hash
    if source? and source !~ URI::REGEXP and source =~ /\w{40}/
      source_uri = base_uri
      source_uri.path = "/source/#{source}"
      self[:source] = source_uri.to_s
    end

    # Merge in object, species, platform_model, platform_type
    inject_platform_deployment_metadata
    
    # Merge in individual if the platform is known to be attached to one, 
    # ie. only if measured >= deployed (and if terminated is set: measured <= terminated)
    inject_indvidual
    
    # Merge in sensor data
    decode_sensor_data
    
    if self[:warn].none?
      self.delete :warn
    end
    
    self
  end
  alias :empty :before_save
  
  protected
  
  def base_uri
    baseuri = URI.parse(ENV["NPOLAR_API"]||"http://localhost")
  end

  def decode_sensor_data

    # For Argos data data prior to 2014-03-01 (DS/DIAG data) the sensor data may either integer or hex
    # Argos data from 2014-03-01 and onwards (XML from SOAP web service) contain both integer and hex data,
    # as well as platform_model string
    
    if sensor_data?
    
      decoder = nil
      
      if self[:platform_model] =~ /^KiwiSat303/i
        
        decoder = Argos::KiwiSat303Decoder.new
        

      elsif self[:platform_model] =~ /^NorthStar/i
        
        decoder = Argos::NorthStar4BytesDecoder.new
        
      end
      
      # Merge in extracted sensor data
      if not decoder.nil?
        
        if self[:sensor_data].is_a? Array and self[:sensor_data].any?
          
          begin

            # @todo HEX from platform deployment metadata
            
            # Arctic fox legacy DS/DIAG data hack: force hex format for platform series 13xxxx
            if self[:object] == "Arctic fox" and self[:platform].to_s =~ /^13/ and self[:technology] == "argos"
              if self[:type] =~ /^(ds|diag)$/
                decoder.sensor_data_format = "hex"
                self[:sensor_data_format] = "hex"
              end
            end
            
            # If we have sensor_hex => use that (then we at least know the base)
            if self.key?(:sensor_hex) and self[:sensor_hex].size >= 2
              decoder.sensor_data = self[:sensor_hex].scan(/[0-9a-f]{2}/i).map {|h| h.to_i(16) }
            else
              decoder.sensor_data = self[:sensor_data]
            end
            
            self[:decoder] = decoder.class.name
            
            decoder.data.each do |k,v|
              self[k]=v
            end
            
            self[:sensor_variables] = decoder.data.keys
          
          rescue
            self[:warn] << "sensor-decoding-failed"
          end
          
        end
        
      end
    
    end
    
  end

  # Get all deployments from Tracking Deployment API database
  def tracking_deployments
    @@deployment ||= begin
      uri = URI.parse(ENV["NPOLAR_API_COUCHDB"])
      uri.path = "/#{Service.factory("tracking-deployment-api").database}"
      client = Npolar::Api::Client::JsonApiClient.new(uri.to_s)
    
      d = client.get_body("_all_docs", {"include_docs"=>true}).rows.map {|row|
        Hashie::Mash.new(row.doc)
      }
      d
    end
  end
    
  # @return [Array] All platforms 
  # We reject all platforms that (reject messages after terminated time)
  # We dont' require the message measured to be after deployed, because the we want platform metadata also 
  def deployments

    measured = DateTime.parse(self[:measured]||self[:positioned])

    begin
      terminated = DateTime.parse(d.deployed)
    rescue
      terminated = DateTime.new(9999)
    end
    
    # From the deployment database
    tracking_deployments.select {|d|
      # Select deployment with the current platform and technology (before terminated time)
      (d.platform.to_s == platform.to_s) and (d.technology == technology) and (measured <= terminated)
    }  
  end
  
  # Get the matching deployment document
  def deployment_hash
    deployment = deployments
    if deployment.size == 1
      deployment[0]
    elsif deployment.size > 1
      next_deployment_after_measured
    else
      {}
    end
  end
  
  def next_deployment_after_measured
    measured = Time.parse(self[:measured]||self[:positioned])
    
    # Simple case first: measured is after deployed and before terminated    
    if idx = deployments.find_index { |d|
      begin
        measured >= Time.parse(d.deployed) and measured <= Time.parse(d.terminated)
      rescue
        # noop
      end
      }
      deployments[idx]
    else
    
      # But for redeployed platforms the problem is that the measured time may be before 2 or more deployed times,
      # we should use deployment neareast in time after measured time
      times = deployments.map { |d| measured.to_i - Time.parse(d.deployed).to_i }
      
      idx = times.find_index {|t| t == times.min }
      
      deployments[idx]
    end
  end
  
  # Merge in individual for periods after deployed and before terminated
  def inject_indvidual
    deployment = deployment_hash
    
    if deployment.key? :individual
    
      begin
        deployed = DateTime.parse(deployment.deployed)
      rescue
        deployed = DateTime.new(1000)
      end
      
      begin
        terminated = DateTime.parse(deployment.terminated)
      rescue
        terminated = DateTime.new(9999)
      end
      
      measured = DateTime.parse(self[:measured]||self[:positioned])
      
      if measured >= deployed and measured <= terminated
        self[:individual] = deployment_hash.individual
      end
    
    end

  end
  
  # Merge in platform deployment information like object, species, platform model
  def inject_platform_deployment_metadata
    
    deployment = deployment_hash
    
    if not deployment.nil? and deployment.key? :id
      deployment_uri = base_uri
      deployment_uri.path = "/tracking/deployment/#{deployment[:id]}"
      self[:deployment] = deployment_uri.to_s
    end
      
    # We add object like "Arctic fox" - also for messages before/after deployment
    if not object? and deployment.key? :object
      self[:object] = deployment.object
    end
    
    # We add species like "Vulpes lagopus" - also for messages before/after deployment
    if not species? and deployment.key? :species
      self[:species] = deployment.species
    end
    
    # Set platform model
    if not platform_model? and deployment.key? :platform_model
      self[:platform_model] = deployment.platform_model
    end
    
    # Set platform type
    if not platform_type? and deployment.key? :platform_type
      self[:platform_type] = deployment.platform_type
    end
    
    # Set platform_name
    if not platform_name? and deployment.key? :platform_name
      self[:platform_name] = deployment.platform_name
    end
        
    # Add deployed and terminated so that we can later compare these with the Tracking Deployment API
    # and and detect if republishing of data for certain platform is needed.
    # This is useful (1) When tagging the deployed date is not yet Tracking Deployment API, but data flow is real time (ie. needs to be fixed after setting the individual)
    # (2) When deployed / terminated / individual data is corrected
    if not deployed? and deployment.key? :deployed
      self[:deployed] = deployment.deployed
    end
    if not terminated? and deployment.key? :terminated
      self[:terminated] = deployment.terminated
    end
  end

end