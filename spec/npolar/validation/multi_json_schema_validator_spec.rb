require "spec_helper"
require "npolar/validation/multi_json_schema_validator"

class Validator < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def scalar(type)
    {
      "$schema" => "http://json-schema.org/draft-04/schema#",
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
          schemas << {type => @validator.scalar(type)}
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
        ["integer", "string"].each do | type |    
          schemas << {type => @validator.scalar(type)}
        end
        @validator.schemas=schemas
      end

      it "true when all are valid" do
        @validator.integer = 7
        @validator.string = "42"
        @validator.valid?.should == true
      end
      
      # Notice this behavior, validation against 1 schema is all that is required for #valid? == true
      it "true when at least one is valid" do
        @validator.integer = 7
        @validator.string = 42
        @validator.valid?.should == true
      end

      it "false when all are invalid" do
        @validator.integer = 3.14
        @validator.string = 42
        @validator.valid?.should == false
      end
      
    end
  
  end
end