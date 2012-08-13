require "spec_helper"

describe Metadata::Rack::Dif do

  subject do
    Metadata::Rack::Dif.new
  end

  def request( path = "/", method = "GET", content_type = "" )
    Npolar::Rack::Request.new(
      Rack::MockRequest.env_for( path, {"REQUEST_METHOD" => method, "CONTENT_TYPE" => content_type } )
    )
  end
  
  context "#condition?" do
    
    context "for a GET request" do
      
      Metadata::Rack::Dif::FORMATS.each do | format |
      
        it "should be true with #{format} as fromat " do
          subject.condition?( request( "/.#{format}" ) ).should be( true )
        end
        
      end
      
      it "should return true when Content-Type: application/xml" do
        subject.condition?( request("/", "GET", "application/xml") ).should be( true )
      end
      
      it "should return false when no format is given" do
        subject.condition?( request ).should be( false )
      end
      
      it "should return false when an unsupported format is given" do
        subject.condition?( request( "/.rdf" ) ).should be( false )
      end
      
    end
    
    context "for a PUT request" do
    
      Metadata::Rack::Dif::ACCEPTS.each do | format |
      
        it "should be true with #{format} as fromat " do
          subject.condition?( request( "/.#{format}", "PUT" ) ).should be( true )
        end
        
      end
      
      it "should return true when Content-Type: application/xml" do
        subject.condition?( request( "/", "PUT", "application/xml" ) ).should be( true )
      end
      
      it "should return false when no format is given" do
        subject.condition?( request( "/", "PUT" ) ).should be( false )
      end
      
      it "should return false when an unsupported format is given" do
        subject.condition?( request( "/.rdf", "PUT" ) ).should be( false )
      end
    
    end
    
    context "for a POST request" do
      
      Metadata::Rack::Dif::ACCEPTS.each do | format |
      
        it "should be true with #{format} as fromat " do
          subject.condition?( request( "/.#{format}", "POST" ) ).should be( true )
        end
        
      end
      
      it "should return true when Content-Type: application/xml" do
        subject.condition?( request( "/", "POST", "application/xml" ) ).should be( true )
      end
      
      it "should return false when no format is given" do
        subject.condition?( request( "/", "POST" ) ).should be( false )
      end
      
      it "should return false when an unsupported format is given" do
        subject.condition?( request( "/.rdf", "POST" ) ).should be( false )
      end
      
    end
    
  end

end
