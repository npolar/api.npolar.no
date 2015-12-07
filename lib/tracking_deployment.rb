require "hashie"

class TrackingDeployment < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["tracking-deployment-1.json"]
  end

end
