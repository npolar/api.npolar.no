require "spec_helper"
require "metadata/dataset"

describe Metadata::Dataset do
  
  subject do
    Metadata::Dataset.new
  end
  
  context "object" do
    
    it "should be a Hash" do
      subject.should be_a_kind_of( Hash )
    end
    
  end
  
  context "schema" do
    
    before( :each ) do
      subject.schema = JSON.parse( File.read( "spec/data/NpMetaSchema.json" ) )
    end
    
    it "should be invalid if the data doesn't meet schema requirements" do
      subject.valid?.should == false
    end
    
    it "should be valid if the minimum requirements set by the schema are met" do
      subject.id = "abc"
      subject.title = "test data"
      subject.license = "http://creativecommons.org/licenses/by/3.0/no/"
      subject.group = "biodiversity"
      subject.progress = "completed"
      subject.valid?.should == true
    end
    
  end
  
end
