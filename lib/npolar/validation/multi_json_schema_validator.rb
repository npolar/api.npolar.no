require "json-schema"
module Npolar
  module Validation

    # JSON Schema validator module for multiple disjoint schemas
    # http://tools.ietf.org/html/draft-zyp-json-schema   
    #
    # Include this module to add #valid? and #errors methods to your model class.
    # Your model needs to provide a #schemas method, see example below.
    # 
    # Usage:
    # require "hashie"
    #
    # class Publication < Hashie::Mash
    #   include Npolar::Validation::MultiJsonSchemaValidator
    #
    #   JSON_SCHEMA = "http://api.npolar.no/schema/publication.json"
    #
    #   JSON_SCHEMA_MINIMAL = "http://api.npolar.no/schema/minimal.json"
    #
    #   def schemas
    #     [{ JSON_SCHEMA => "publication.json",
    #       JSON_SCHEMA_MINIMAL => "minimal.json"}]
    #   end
    #
    # end
    module MultiJsonSchemaValidator

      # Local disk cache of JSON schemas
      JSON_SCHEMA_DISK = ENV["NPOLAR_VALIDATION_JSON_SCHEMA"] ||= File.expand_path(File.join(
        File.dirname(__FILE__), "..", "..", "..", "schema"))

      
      attr_reader :errors  # Validation results (set by #valid?)
      attr_writer :schemas # User-provided Array { uri => path }
      
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
      def valid?(context=nil)
        @errors = []
        if schemas.nil? or [] == schemas
          raise "Class #{self.class.name} lacks JSON schemas"
        end
        schemas.each_with_index do |schema_hash|
          schema_hash.each do |uri, path| 
          
            # Allow schemas to be URIs
            if path.nil?
              schema=uri
            else

            # User provided a schema, not a path to one
            if path.is_a? Hash
              schema = path
            else
              # Prefix disk cache if path is relative
              unless path[0] == "/"
                path = JSON_SCHEMA_DISK.gsub(/\/$/, "")+"/"+path
              end              
              schema=File.read path
            end

            end
            #p "JSON Schema Validator: #{uri} [#{path}]"
        
            result = JSON::Validator.fully_validate(schema, self, :errors_as_objects => false).flatten.map {|e|
              if e =~ /\sin schema\s/
                e.split(" in schema ")[0]
              else
                e
              end
            }

            if result.any?
              @errors << {
                :schema => uri,
                :result => result
              }

            else
              # Return true on first valid document
              return true
            end

          end # this schema
        end # all schemas

        false

      end

    end
  end
end