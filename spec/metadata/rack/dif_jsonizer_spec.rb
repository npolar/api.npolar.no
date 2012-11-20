require "spec_helper"

describe Metadata::Rack::DifJsonizer do

  subject do
    test_app = mock( "Test Application", :call => Npolar::Rack::Response.new(
      StringIO.new('{"message": "Ok"}'), 200, {"Content-Type" => "application/xml"} ) )
    
    @app ||= Metadata::Rack::DifJsonizer.new( test_app )
  end
  
  context "#condition?" do
    
    context "for a GET request" do
      
      Metadata::Rack::DifJsonizer::FORMATS.each do | format |
      
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
    
      Metadata::Rack::DifJsonizer::ACCEPTS.each do | format |
      
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
      
      Metadata::Rack::DifJsonizer::ACCEPTS.each do | format |
      
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
  
  context "#handle" do
    
    it "should call #dif_from_json if request method is GET" do
      subject.stub( :dif_from_json ) { "read" }
      subject.handle( request ).should == "read"
    end
    
    it "should call #dif_save if request method is PUT" do
      subject.stub( :dif_save ) { "write" }
      subject.handle( request( "/", "PUT" ) ).should == "write"
    end
    
    it "should call #dif_save if request method is PUT" do
      subject.stub( :dif_save ) { "write" }
      subject.handle( request( "/", "POST" ) ).should == "write"
    end
    
  end
  
  context "when saving DIF" do
    
    context "#dif_save" do
      
      before( :each ) do
        @env = request( "/", "PUT", "application/xml" )
        data = StringIO.new( File.read( "spec/data/dif_record.xml" ) )
        @env["rack.input"] = ::Rack::Lint::InputWrapper.new( data )
        
        # Stub the call method so it returns what we put in
        test_app = mock
        test_app.stub!( :call ) do | arg |
          arg
        end
        
        @app = Metadata::Rack::DifJsonizer.new( test_app )
      end
      
      it "should convert DIF XML to the native format" do
        request = ::Rack::Request.new( @env )
        subject.dif_save( request )["rack.input"].read.should
          include( "title", "contributors", "category" )
      end
      
      it "should change the content type to application/json" do
        request = ::Rack::Request.new( @env )
        subject.dif_save( request )["CONTENT_TYPE"].should == "application/json"
      end
      
      it "should set the content length" do
        request = ::Rack::Request.new( @env )
        subject.dif_save( request )["CONTENT_LENGTH"].should_not == "0"
      end
      
    end
    
  end
  
  context "When converting native format to DIF" do
    
    context "#dif_from_json" do
      
      context "with response status < 300" do
        
        before(:each) do
          subject.stub(:dif_json) {}
        end
      
        ["dif", "xml", "iso"].each do | format |
          
          it "should return XML for requests with .#{format} exstension" do
            subject.stub(:dif_xml) { "<#{format}>data</#{format}>" }
            subject.stub(:iso) { "<iso>data</iso>" }
            
            status, headers, body = subject.dif_from_json( request("/.#{format}") )
            body.first.should == "<#{format}>data</#{format}>"
          end
          
        end
        
        it "should return XML for requests with .atom exstension" do
          subject.stub(:atom_entry) { ::Atom::Entry.new( :title => "atom" ) }
          
          status, headers, body = subject.dif_from_json( request("/.atom") )
          body.first.should include( "<title>atom</title>" )
        end
        
        it "should validate the XML when getting a request for .xml/validate" do
          subject.stub(:dif_xml) { "<xml>data</xml>" }
          Gcmd::Schema.any_instance.stub( :validate_xml ).and_return( "message" => "valid" )
          status, headers, body = subject.dif_from_json( request("/.xml/validate") )
          body.first.should == '{"message":"valid"}'
        end
      
      end
      
      context "with response status > 300" do
        
        it "should pass on the response" do
          test_app = mock("Fail Test", :call => Npolar::Rack::Response.new(
            StringIO.new('{"message": "Not Ok"}'), 500, {"Content-Type" => "application/xml"} ) )
          @app = Metadata::Rack::DifJsonizer.new( test_app )
          
          response = subject.dif_from_json( request )
          response.body.first.should == '{"message": "Not Ok"}'
        end
        
      end
      
    end
    
  end
  
  context "Protected" do
    
    context "#dif_json" do
      
      it "should call a conversion from native hash to dif hash" do
        Metadata::DifTransformer.any_instance.stub( :to_dif ).and_return( true )
        subject.send( :dif_json, {} ).should be( true )
      end
      
    end
    
    context "#dif_xml" do
      
      it "should call a conversion from dif hash to DIF XML" do
        ::Gcmd::DifBuilder.any_instance.stub( :build_dif ).and_return( true )
        subject.send( :dif_xml, {} ).should be( true )
      end
      
    end
    
    context "#atom_entry" do
      
      it "should return atom XML from an atom hash" do
        hash = JSON.parse( File.read( "spec/data/atom_hash.json" ) )
        subject.send( :atom_entry, hash).to_xml.should include("<title>myTitle</title>")
      end
      
    end
    
  end
  
  private
  
  def request( path = "/", method = "GET", content_type = "" )
    Npolar::Rack::Request.new(
      Rack::MockRequest.env_for( path, {"REQUEST_METHOD" => method, "CONTENT_TYPE" => content_type } )
    )
  end

end
