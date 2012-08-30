require "spec_helper"
require "metadata/dataset"

describe Metadata::Dataset do
  
  subject do
    Metadata::Dataset.new
  end
  
  context "object" do
    
    it "should have an id if provided with one" do
      dataset = Metadata::Dataset.new( {"id" => "abc"} )
      dataset.id.should eq( "abc" )
    end
    
  end
  
end
