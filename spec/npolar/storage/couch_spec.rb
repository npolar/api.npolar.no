require "spec_helper"
require "npolar/storage/couch.rb"
require "pp"

describe Npolar::Storage::Couch do

  before(:each) do
    @couch = Npolar::Storage::Couch.new("thing")
  end

  context "#post" do
    it "POST-ing single document, if PUT gives us 409, post() should return 409" do
      @couch.stub(:writer) {  
        double(::Rack::Client.new("uri"), :put => Npolar::Rack::Response.new("", 409, {"Content-Type" => "application/json"}))
      }
      status, headers, body = @couch.post({ "id" => "12345a", "foo" => "bar" }.to_json)
      status.should == 409
    end

    it "POST-ing single document, if PUT gives us 201, post() should return 201" do
      @couch.stub(:writer) {  
        double(::Rack::Client.new("uri"), :put => Rack::MockResponse.new(201, {"Content-Type" => "application/json"}, [{'id' => '12345a', 'rev' =>'54321b'}.to_json]))
      }

      @couch.stub(:reader) {
        double(::Rack::Client.new("uri"), :get => Rack::MockResponse.new(201, {"Content-Type" => "application/json"}, [{'id' => '12345a', 'rev' =>'54321b'}.to_json]))
      }

      resp = Rack::MockResponse.new(201, {"Content-Type" => "application/json"}, [{'id' => '12345a', 'rev' =>'54321b'}.to_json])

      status, headers, body = @couch.post({ "id" => "12345a", "foo" => "bar" }.to_json)
      status.should == 201
    end
  end

  context "#post_many" do
    it "with no overwrite and posting conflicting records, expect 409" do
      @couch.stub(:writer) {
        double(::Rack::Client.new("uri"), :post => Rack::MockResponse.new(409, {"Content-Type" => "application/json"},[ [{ "id" => 1, "error" => "conflict"}, { "id" => 2, "error" => "conflict"}, {"id" => 3}, {"id" => 4}].to_json ]))
      }

      status, headers, body = @couch.post_many([{"id" => 1}, {"id" => 2}, {"id" => 3}, {"id" => 4}].to_json)
      message = Yajl::Parser.parse(body[0])
      message.should have_key("error")
      message["error"].should have_key("status")
      message["error"]["status"].should == 409
    end

    it "with no overwrite and posting OK records, expect 201" do
      @couch.stub(:writer) {
        double(::Rack::Client.new("uri"), :post => Rack::MockResponse.new(201, {"Content-Type" => "application/json"},[ [{ "id" => 1}, { "id" => 2}, {"id" => 3}, {"id" => 4}].to_json ]))
      }

      status, headers, body = @couch.post_many([{"id" => 1}, {"id" => 2}, {"id" => 3}, {"id" => 4}].to_json)
      message = Yajl::Parser.parse(body[0])
      message.should have_key("response")
      message["response"].should have_key("status")
      message["response"]["status"].should == 201
    end

    it "with overwrite=true and posting conflicting records, expect 201" do
      client = double(::Rack::Client.new("uri"))
      client.stub(:post).and_return( Rack::MockResponse.new(409, {"Content-Type" => "application/json"}, [ [{ "id" => 1, "error" => "conflict"}, { "id" => 2, "error" => "conflict"}, {"id" => 3}, {"id" => 4}].to_json ]),
                                     Rack::MockResponse.new(201, {"Content-Type" => "application/json"}, [ "" ]) ) 

      @couch.stub(:writer) { client }
      @couch.stub(:fetch_many) { 
        [ 201, 
          {"Content-Type" => "application/json"},
          { "rows" => 
            [
              { 
                "id" => "1", 
                "value" => { "rev" => "asdf1" } 
              }
            ]
          }.to_json 
        ]
      }

      status, headers, body = @couch.post_many([{"id" => 1}, {"id" => 2}, {"id" => 3}, {"id" => 4}].to_json, { "overwrite" => "true" })
      message = Yajl::Parser.parse(body[0])
      message.should have_key("response")
      message["response"].should have_key("status")
      message["response"]["status"].should == 201
    end

  end
  
  context "#update_revision" do
    it "if doc has an id matching one in db, _rev should be updated" do
      @couch.stub(:get => [200, "asdf", { "id" => "a100a", "_rev" => "2343434fdfdfdfdf", "foo" => "bar"}.to_json])
      doc = @couch.send(:update_revision, { "id" => "a100a", "_rev" => "afafafafaf333"})
      doc["_rev"].should == "2343434fdfdfdfdf"
    end
  end

  context "#ids_from_response" do
    it "with resp.body = [{'id' => 100}, {'id' => 200}, {'id' => 300}] (in json), we expect [100, 200, 300]" do
      resp = Npolar::Rack::Response.new("", 200, {"Content-Type" => "application/json"})
      resp.stub(:body) { [{'id' => '100'}, {'id' => '200'}, {'id' => '300'}].to_json }

      ids = @couch.send(:ids_from_response, resp)
      ids.length.should == 3
      ids[0].should == "100"
      ids[1].should == "200"
      ids[2].should == "300"
    end
  end

  context "#self.force_ids" do
    it "doc with a non-empty _id => id = _id" do
      test = { "_id" => "afff3333cccccddddeee", "foo" => "bar"}
      doc = Npolar::Storage::Couch::force_ids(test)
      doc["_id"].should == test["_id"] and doc["id"].should == test["_id"]
    end

    it "doc with _id undefined and id non-empty => _id = id" do
      test = { "id" => "afff3333cccccddddeee", "foo" => "bar"}
      doc = Npolar::Storage::Couch::force_ids(test)
      doc["_id"].should == test["id"] and doc["id"].should == test["id"]
    end

    it "doc with id, _id undefined => id, _id generated" do
      test = { "foo" => "bar" }
      doc = Npolar::Storage::Couch::force_ids(test)
      (doc.has_key? "_id").should == true and doc["_id"].to_s.empty?.should == false
      (doc.has_key? "id").should == true and doc["id"].to_s.empty?.should == false
    end
  end
end

