require "spec_helper"

describe Metadata::Rack::Dif do

  subject do
    Metadata::Rack::Dif.new
  end

  context "#condition?" do
    
    context "for a GET request" do
      
      Metadata::Rack::Dif::FORMATS.each do | format |
      
        it "should be true with #{format} as fromat " do
          request = Npolar::Rack::Request.new( Rack::MockRequest.env_for( "/.#{format}" ) )
          subject.condition?( request ).should be( true )
        end
        
      end
      
      it "should return true when Content-Type: application/xml" do
        request = Npolar::Rack::Request.new(
                    Rack::MockRequest.env_for( "/", { "CONTENT_TYPE" => "application/xml" } )
                  )
        subject.condition?( request ).should be( true )
      end
      
    end
    
    context "for a PUT request" do
    
      Metadata::Rack::Dif::ACCEPTS.each do | format |
      
        it "should be true with #{format} as fromat " do
          request = Npolar::Rack::Request.new(
                      Rack::MockRequest.env_for( "/.#{format}", {"REQUEST_METHOD" => "PUT"} )
                    )
          subject.condition?( request ).should be( true )
        end
        
      end
      
      it "should return true when Content-Type: application/xml" do
        request = Npolar::Rack::Request.new(
                    Rack::MockRequest.env_for( "/abc", { "REQUEST_METHOD" => "PUT",
                                                         "CONTENT_TYPE" => "application/xml" } )
                  )
        subject.condition?( request ).should be( true )
      end
    
    end
    
    context "for a POST request" do
      
      Metadata::Rack::Dif::ACCEPTS.each do | format |
      
        it "should be true with #{format} as fromat " do
          request = Npolar::Rack::Request.new(
                      Rack::MockRequest.env_for( "/.#{format}", {"REQUEST_METHOD" => "POST"} )
                    )
          subject.condition?( request ).should be( true )
        end
        
      end
      
      it "should return true when Content-Type: application/xml" do
        request = Npolar::Rack::Request.new(
                    Rack::MockRequest.env_for( "/", { "REQUEST_METHOD" => "POST",
                                                      "CONTENT_TYPE" => "application/xml" } )
                  )
        subject.condition?( request ).should be( true )
      end
      
    end
    
  end

end
