require "spec_helper"
require "metadata/dataset/dif_transformer"

describe Metadata::Dataset::DifTransformer do
  
  subject do
    Metadata::Dataset::DifTransformer.new
  end
  
  context "Object" do
    
    it "should be a Hash" do
      subject.should be_a_kind_of( Hash )
    end
    
  end
  
  context "#format" do
    
    it "should return dif when a DIF hash" do
      transformer = Metadata::Dataset::DifTransformer.new( {"Entry_ID" => "abc"} )
      transformer.format.should == "dif"
    end
    
    it "should return dataset when a metadata hash" do
      transformer = Metadata::Dataset::DifTransformer.new( {"id" => "abc"} )
      transformer.format.should == "dataset"
    end
    
    it "should be nil when nothing is set" do
      subject.format.should be( nil )
    end
    
  end

end