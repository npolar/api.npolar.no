require "json-schema"

module Npolar
  module Validation

    # JSON schema validator module for multiple schemas
    # http://tools.ietf.org/html/draft-zyp-json-schema   
    #
    # Include this module in a Hashie::Mash, or other Ruby object,
    # to add the methods #valid? and #errors. The model needs to provide
    # a #schemas method that should return an Array of schema references,
    # either URIs or paths.
    # 
    # Usage:
    # require "hashie"
    #
    # class Publication < Hashie::Mash
    #   include Npolar::Validation::MultiJsonSchemaValidator
    #
    #   def schemas
    #     ["publication.json", "minimal.json"]
    #   end
    #
    # end
    module MultiJsonSchemaValidator

      # Local disk cache of JSON schemas
      JSON_SCHEMA_DISK = ENV["NPOLAR_VALIDATION_JSON_SCHEMA"] ||= File.expand_path(File.join(
        File.dirname(__FILE__), "..", "..", "..", "schema"))

      attr_writer :schemas # User-provided Array of schemas, each Hash | string filename | string JSON

      # Validation errors
      def errors(schema=nil)
        if @errors.nil?
          valid?
        end
        @errors
      end
      
      # Implement in model
      def schemas(context=nil)
        if @schemas.nil? or [] == @schemas
          raise "Class #{self.class.name} lacks JSON schemas"
        end
        @schemas
      end

      # Returns true on the first successful validation (does not require validation against all schemas)
      # Sets @error to Array of error reports
      # @return true|false
      # @raises Exception on blank or invalid schemas
      def valid?(context=nil)
        @errors = []

        if schemas.nil? or [] == schemas
          raise "Class #{self.class.name} lacks JSON schemas"
        end

        schemas.each do |schema|

          # Use schema from disk if it's not a Hash
          unless schema.is_a? Hash
            # Prefix disk cache if path is relative
            unless schema[0] == "/"
              schema = JSON_SCHEMA_DISK.gsub(/\/$/, "")+"/"+schema
            end
          end

          # FIXME validate schema and raise Exception
          result = JSON::Validator.fully_validate(schema, self,
            :errors_as_objects => true, :validate_schema => false,
            :insert_defaults => true).flatten

          if result.any?
            @errors += result
          else
            # Return true on first valid document
            return true
          end

        end # schemas loop
        
        false # if no schema returned true, it's false (invalid)

      end

    end
  end
end