require "spec_helper"
require "metadata/dif_transformer"

describe Metadata::DifTransformer do
    
  context "Object" do
    
    it "should raise an Argumenterror the data isn't a Hash" do
      expect{ Metadata::DifTransformer.new( [] ) }.to raise_error( ArgumentError )
    end
    
    it "should be a Hash when provided with valid data" do
      transformer = Metadata::DifTransformer.new
      subject.object.should be_a_kind_of( Hash )
    end
    
  end
  
  context "Transformations" do
    
    before(:each) do
      @transformer = Metadata::DifTransformer.new( JSON.parse( File.read( "spec/data/dif.json" ) ) )
    end
    
    context "#to_dataset" do
      
      it "should return a Hash" do
        @transformer.to_dataset.should be_a_kind_of( Hash )
      end
      
      context "#source" do
        
        it "should save a copy of the dif under source" do          
          source = @transformer.source
          source.dif.should == @transformer.object
        end
        
      end
      
      context "#id" do
      
        it "should map Entry_ID to id" do
          @transformer.id.should == @transformer.object.Entry_ID
        end
        
      end
      
      context "#title" do
        
        it "should map Entry_Title to title" do
          @transformer.title.should == @transformer.object.Entry_Title
        end
        
      end
      
      context "#tags" do
        
        it "should map Keyword to Tags" do
          @transformer.tags.should == @transformer.object.Keyword
        end
        
      end
      
      context "#quality" do
        
        it "should map Quality to quality" do
          @transformer.quality.should == @transformer.object.Quality
        end
        
      end
      
      context "#rights" do
        
        it "should map Use_Constraints to rights" do
          @transformer.rights.should == @transformer.object.Access_Constraints
        end
        
      end
      
      context "#published" do
        
        it "should map DIF_Creation_Date to published" do
          @transformer.published.should include( @transformer.object.DIF_Creation_Date )
        end
        
        it "should format the date to ISO 8601 Date Time format" do
          @transformer.published.should =~ Metadata::DifTransformer::ISO_8601
        end
        
      end
      
      context "#updated" do
        
        it "should map Last_DIF_Revision_Date to updated" do
          @transformer.updated.should include( @transformer.object.Last_DIF_Revision_Date )
        end
        
        it "should format the date to ISO 8601 Date Time format" do
          @transformer.updated.should =~ Metadata::DifTransformer::ISO_8601
        end
        
      end
      
      context "#progress" do
        
        it "should return a string" do
          @transformer.progress.should be_a_kind_of( String )
        end
        
        it "should change In Work to ongoing" do
          @transformer.progress.should == "ongoing"
        end
        
      end
      
      context "#activity" do
        
        it "should return an Array" do
          @transformer.activity.should be_a_kind_of( Array )
        end
        
        it "should map Temporal_Coverage to activity" do
          @transformer.activity[0].start_date.should == @transformer.object.Temporal_Coverage[0].Start_Date
        end
        
      end
      
      context "#summary" do
        
        it "should be a String" do
          @transformer.summary.should be_a_kind_of( String )
        end
        
        it "should map Summary[Abstract] to summary" do
          @transformer.summary.should == "A brief exploration of the alphabet."
        end
        
        it "should check if Summary contains the a string directly (old dif versions)" do
          @transformer.object.Summary = "my summary"
          @transformer.summary.should == "my summary"
        end
        
        it "should return an empty string if no summary is available" do
          @transformer.object.Summary = nil
          @transformer.summary.should == ""
        end
        
      end
      
      context "#role_handler" do
        
        it "should return an array" do
          @transformer.role_handler( "Investigator" ).should be_a_kind_of( Array )
        end
        
        it "should raise an ArgumentError if an unknown role is given" do
          expect{ @transformer.role_handler( "Alien Overlord" ) }.to raise_error( ArgumentError )
        end
        
      end
      
      context "#investigators" do
        
        it "should return an array" do
          @transformer.investigators.should be_a_kind_of( Array )
        end
        
        it "should include all DIF:personnel with the investigator role" do
          @transformer.investigators[0].should include( "first_name" => "R e", "last_name" => "Dux" )
        end
        
      end
      
      context "#editors" do
        
        it "should return an array" do
          @transformer.editors.should be_a_kind_of( Array )
        end
        
        it "should include all DIF:personnel with the dif Author role" do
          @transformer.editors[0].should include( "first_name" => "John", "last_name" => "Doe" )
        end
        
        it "should set edited to Last_DIF_Revision_Date" do
          @transformer.editors[0].should include( "edited" => "2012-09-03T12:00:00Z" )
        end
        
      end
      
      context "#contributors" do
        
        it "should return an array" do
          @transformer.contributors.should be_a_kind_of( Array )
        end
        
        it "should include DIF:personnel with the role of Technical Contact in contributors" do
          @transformer.contributors[0].should include( "first_name" => "John", "last_name" => "Doe" )
        end
        
        it "should not include Technical Contacts that are also investigators" do
          @transformer.contributors.should_not include( "first_name" => "R", "last_name" => "Dux" )
        end
        
      end
      
      context "#locations" do
        
        it "should return an array" do
          @transformer.locations.should be_a_kind_of( Array )
        end
        
        it "should map Spatial_Coverage(coordinates) to a location " do
          @transformer.locations[0].north.should == 90
        end
        
        it "should map Locations[detailed_location] to locations" do
          @transformer.locations[2].placename.should == "Pyramiden"
        end
        
      end
      
      context "#science_keywords( DIF Paramters )" do
        
        it "should map DIF parameters to science keywords" do
          @transformer.science_keywords.should == @transformer.object.Parameters
        end
        
      end
      
      context "#draft" do
        
        it "should default to no on import" do
          @transformer.draft.should == "no"
        end
        
      end
      
    end
    
  end

end
