require "spec_helper"
require "npolar/validation/multi_json_schema_validator"

class Validator < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  # Scalar schema generator
  def scalar(type)
    {
      "$schema" => "http://json-schema.org/draft-04/schema#",
      "id" => "http://example.com/schema/scalar/#{type}",
      "type" => "object",
      "properties" => {
        type => {"type" => type},
      }
    }
  end
end

describe Npolar::Validation::MultiJsonSchemaValidator do

  context "#schemas" do

    before(:each) do
      @validator = Validator.new
    end

    it "Exception if not set" do
      lambda { @validator.valid? }.should raise_exception
    end
    it "Exception if []" do
      @validator.schemas=[]
      lambda { @validator.valid? }.should raise_exception
    end

  end

  context "#valid?" do

    context "1 schema" do

      before (:each) do
        @validator = Validator.new
        schemas = []
        ["integer"].each do | type |    
          schemas << @validator.scalar(type)
        end
        @validator.schemas=schemas
      end

      it "true when zero errors" do
        @validator.integer = 5
        @validator.valid?.should == true
      end
      
      it "false when failing to validate" do
        @validator.integer = "3.14"
        @validator.valid?.should == false
      end
    end

    context "multiple schema" do

      before (:each) do
        @validator = Validator.new
        schemas = []
        ["integer", "string", "boolean"].each do | type |    
          schemas << @validator.scalar(type)
        end
        @validator.schemas=schemas
      end

      it "true when all are valid" do
        @validator.integer = 7
        @validator.string = "42"
        @validator.boolean = true
        @validator.valid?.should == true
      end
      
      # Notice this behavior, validation against 1 schema is all that is required for #valid? == true
      it "true when at least one is valid" do
        @validator.integer = 7
        @validator.string = 42
        @validator.boolean = "false-string"
        @validator.valid?.should == true
      end

      it "false when all are invalid" do
        @validator.integer = 3.14
        @validator.string = 42
        @validator.boolean = "true-string"
        @validator.valid?.should == false
      end
      
    end

    context "at least one invalid schema" do
      it "Exception on at least one invalid schema" do
        validator = Validator.new
        validator.schemas=[validator.scalar("null"), {"bad"=>"schema"}]
        lambda { validator.schemas }.should raise_exception
      end
    end

  end

  context "#errors" do
    before (:each) do
      @validator = Validator.new
      schemas = []
      ["string", "boolean"].each do | type |    
        schemas << @validator.scalar(type)
      end
      @validator.schemas=schemas
      @validator.string = 42
      @validator.boolean = "not"
        
    end

    it do
      JSON.parse(@validator.errors.to_json).should == [{"schema"=>"http://example.com/schema/scalar/string#", "fragment"=>"#/string", "message"=>"The property '#/string' of type Fixnum did not match the following type: string in schema http://example.com/schema/scalar/string#", "failed_attribute"=>"TypeV4"}, {"schema"=>"http://example.com/schema/scalar/boolean#", "fragment"=>"#/boolean", "message"=>"The property '#/boolean' of type String did not match the following type: boolean in schema http://example.com/schema/scalar/boolean#", "failed_attribute"=>"TypeV4"}]
    end

  end
end

 