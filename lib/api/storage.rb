module Api
  module Storage

    # From http://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-constantize
    # activesupport/lib/active_support/inflector/methods.rb, line 107
    def self.factory(depot, config)

      if depot.nil?
        raise Api::Exception("No storage adapter given")
      end
      require "#{File.dirname(__FILE__)}/storage/#{depot.downcase}"

      names = ["Api", "Storage", depot.capitalize]
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
      end
      constant.new(config)
    end
  end
end
