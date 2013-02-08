require "spec_helper"
require "npolar/rack/disk_storage"

describe Npolar::Rack::DiskStorage do
  
  before(:each) do
    @data = File.open( "spec/data/test.nc", "rb" ){|io| io.read}
    @env = Rack::MockRequest.env_for(
      "/metadata/dataset/test.nc",
      "REQUEST_METHOD" => "PUT",
      "rack.input" => StringIO.new(@data)
    )
     
  end
  
  subject do
    app = mock("file storage", :call => Npolar::Rack::Response.new(
      StringIO.new(@data), 200, {"Content-Type" => "application/netcdf"}))
    
    app.stub( :call ) { Npolar::Rack::Response.new([ { "id" => "1234asdf", "ok" => true }.to_json ], 201, {}) }
    
    Npolar::Rack::DiskStorage.new(
      app,
      {
        :format => ["nc"],
        :type => [/application\/netcdf/],
        :file_root => "/tmp"
      }
    )
  end
  
  context "#condition?" do
    
    it "should be true when PUT with the given format" do
      subject.condition?(Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    it "should be true when POST with the given format" do
      @env["REQUEST_METHOD"] = "POST"
      subject.condition?(Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    it "should be true when PUT with the given type" do
      @env["PATH_INFO"] = "/test"
      @env["CONTENT_TYPE"] = "application/netcdf"
      subject.condition?(Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    it "should be true when POST with the given type" do
      @env["PATH_INFO"] = "/test"
      @env["CONTENT_TYPE"] = "application/netcdf"
      @env["REQUEST_METHOD"] = "POST"
      subject.condition?(Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    it "should be false when not the correct format" do
      @env = Rack::MockRequest.env_for("/test.xlsx", "REQUEST_METHOD" => "PUT")
      subject.condition?(Npolar::Rack::Request.new(@env)).should be(false)
    end
    
  end

  context "#path" do
    it "should give us path ending with format" do
      filepath = subject.send(:path, "1234asdf", Npolar::Rack::Request.new(@env))
      File.extname(filepath).should == ".nc"
    end
  end

  context "#doc_root" do
    it "should give use /tmp/metadata/dataset/1234asdf" do
      root = subject.send(:doc_root, "1234asdf", Npolar::Rack::Request.new(@env))
      root.should == "/tmp/metadata/dataset/1234asdf"
    end
  end
  
  context "#handle" do
    it "should not raise an exception when id is provided" do
      expect{ subject.handle(Npolar::Rack::Request.new(@env))}.to_not raise_error(Exception)
    end
  end

  context "#save_to_disk" do
    
    it "should write a file to disk" do
      filepath = subject.send(:path, "1234asdf", Npolar::Rack::Request.new(@env))
      subject.save_to_disk(filepath, "content")
      
      File.open(filepath, "rb").should_not be(nil)
    end
    
    it "should raise an exception when an error occurs" do
      expect{ subject.save_to_disk(nil, nil) }.to raise_error(Exception)
    end
    
  end

  context "#handle_get" do
    before(:each) do
      @get_env = Rack::MockRequest.env_for(
        "/metadata/dataset/1234asdf.nc",
        "REQUEST_METHOD" => "GET",
        "REQUEST_URI" => "/metadata/dataset/1234asdf.nc",
        "rack.input" => StringIO.new(@data)
      )

      # make sure file is there
      filepath = subject.send(:path, "1234asdf", Npolar::Rack::Request.new(@env))
      FileUtils.mkdir_p(File.dirname(filepath))
      File.open(filepath, "wb") do |f|
        f.write("content")
      end
    end

    it "should return 200" do
      response = subject.handle_get(Npolar::Rack::Request.new(@get_env))
      response[0].should == 200
    end

    it "should create a file for us with same content as we fed the middleware initially" do
      response = subject.handle_get(Npolar::Rack::Request.new(@get_env))
      content = response[2].read
      content.should == "content"
    end

  end

  context "#handle_delete" do
    before(:each) do
      @del_env = Rack::MockRequest.env_for(
        "/test.nc",
        "REQUEST_METHOD" => "DELETE",
        "rack.input" => StringIO.new(@data)
      )
      # make sure file is there
      filepath = subject.send(:path, "1234asdf", Npolar::Rack::Request.new(@env))
      FileUtils.mkdir_p(File.dirname(filepath))
      File.open(filepath, "wb") do |f|
        f.write("content")
      end
    end

    it "should not raise an exception when id is provided and method=POST" do
      expect{ subject.handle(Npolar::Rack::Request.new(@del_env))}.to_not raise_error(Exception)
    end

    it "should remove the file we posted" do
      subject.handle_delete(Npolar::Rack::Request.new(@del_env))
      #filepath = subject.send(:path, "1234asdf", Npolar::Rack::Request.new(@del_env))
      expect { File.open(filepath, "rb") }.to raise_error(Exception)
    end

  end
  
  context "#format?" do
    
    it "should be true if the request format equals the configured format" do
      subject.send(:format?, Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    it "should be false if the request format isn't the configured format" do
      @env = Rack::MockRequest.env_for("/test.xlsx")
      subject.send(:format?, Npolar::Rack::Request.new(@env)).should be(false)
    end
    
  end
  
  context "#content_type?" do
    
    it "should be true if the request type equals the configured type" do
      @env = Rack::MockRequest.env_for("/test", "CONTENT_TYPE" => "application/netcdf")
      subject.send(:content_type?, Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    it "should be false if the request type isn't the configured type" do
      @env = Rack::MockRequest.env_for("/test", "CONTENT_TYPE" => "application/xml")
      subject.send(:content_type?, Npolar::Rack::Request.new(@env)).should be(false)
    end
    
  end
  
  context "#write?" do
    
    it "should be true when PUT" do
      subject.send(:write?, Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    it "should be true when POST" do
      @env["REQUEST_METHOD"] = "POST"
      subject.send(:write?, Npolar::Rack::Request.new(@env)).should be(true)
    end
    
    ["GET", "HEAD", "PATCH", "OPTIONS", "DELETE", "TRACE", "CONNECT"].each do |req_method|
      it "should be false when #{req_method}" do
        @env["REQUEST_METHOD"] = req_method
        subject.send(:write?, Npolar::Rack::Request.new(@env)).should be(false)
      end
    end
    
  end
  
end
