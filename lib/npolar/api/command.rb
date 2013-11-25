module Npolar
  module Api 
    class Command

      def self.level(level_string, fallback=Logger::INFO)
      
        case level_string
          when /debug|0/i
            Logger::DEBUG
          when /info|1/i
            Logger::INFO
          when /warn|2/i
            Logger::WARN
          when /error|3/i
            Logger::ERROR
          when /fatal|4/i
            Logger::FATAL
          else
            fallback  
        end
      end
    end
  end
end