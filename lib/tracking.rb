module Tracking
  class << self
    attr_accessor :collections
  end

  def self.workspace
    "iridium"
  end
end