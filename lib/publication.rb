require "hashie"

# @todo WIP
class Publication < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["publication-1.json"]
  end

  # Process incoming publication(s) before storage interaction
  # @return lambda
  # See Core#handle and Core#before
  def self.before
    lambda {|request|
      if request.put? or request.post?
        Publication.before_save(request)
      else
        request
      end
    }
  end

  def self.before_save(request)
    request
  end

  def before_save(args)
    request
    # N-ICE2015 programme? => force set
    # N-ICE2015 set? => force program
    # N-ICE2015? => force project relation link
  end

end
