module Npolar
  module Api
    class << self
      attr_accessor :workspaces, :hidden_workspaces
      attr_accessor :models
      attr_writer   :log
    end
    
    def self.log
      @@log ||= begin
        log = Logger.new(STDERR)
        log.level = case ENV["RACK_ENV"]
          when "development" then log.level = Logger::DEBUG
          when "test" then log.level = Logger::UNKNOWN
          when "production" then log.level = Logger::INFO
        end
        log
      end

    end

  end
end
