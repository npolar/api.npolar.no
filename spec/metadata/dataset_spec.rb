# encoding: utf-8
require "spec_helper"
require "metadata/dataset"

describe Metadata::Dataset do
  
  before do
    @dataset = Metadata::Dataset.new
  end
  
  it do
    @dataset.should be_a_kind_of Hashie::Mash 
  end

  context "Validation" do
    context "{}" do
      
      context "#valid?" do
        it do
          @dataset.valid?.should == false
        end
      end
      context "errors (required properties)" do
        it do
          @dataset.errors.map {|e|
            m = e[:message].split("did not contain a required property of '")
            m = m.any? ? m[1].split("'")[0] : ""
          }.should == ["title"]
        end
      end
    end 
    context '{"title": "T1"}' do
      context "#valid?" do
        it do
          @dataset.title = "T1"
          @dataset.schema = "http://api.npolar.no/schema/dataset"
          @dataset.valid?.should == true
        end
      end    
    end
  end
  context "Data policy" do
    context "before" do

      it "Metadata::Dataset.before returns a lambda" do
        Metadata::Dataset.before.should.respond_to?(:call)
      end

      it "before_save only on POST or PUT"

      before (:each) do
        env = Rack::MockRequest.env_for("/", { :method => "POST", "CONTENT_TYPE" => "application/json" })
        @request = Npolar::Rack::Request.new(env)
        @request.body="{}"
        
        def before_save(request=@request)
          response = Metadata::Dataset.before_save(request)
          Metadata::Dataset.new(JSON.parse(response.body.read))
        end
      end

      context "Saving empty {}" do
          
        context "licences" do
          it do
            before_save.licences.should == ["http://data.norge.no/nlod/no/1.0", "http://creativecommons.org/licenses/by/3.0/no/"]
          end
        end

        context "collection" do
          it do
            before_save.collection.should == "dataset"
          end
        end

        context "progress" do
          it do
            before_save.progress.should == "planned"
          end
        end

        context "#open?" do
          it do
            before_save.open?.should == true
          end
        end

        context "#rights" do
          it do
            before_save.rights.should =~ /Open data. Free to reuse if attributed to the Norwegian Polar Institute./
          end
        end

        context "draft" do
          it "yes" do
            @request.body='{"draft":"no"}' 
            before_save.draft.should == "yes"
          end
        end

        context "#draft?" do
          it do
            @request.body='{"draft":"no"}' 
            before_save.draft?.should == true
          end
        end

        context "organisations" do
          context "id" do
            it do
              before_save.organisations[0].id.should == "npolar.no"
            end
          end
            context "roles" do
            it  do
              before_save.organisations[0].roles.should == ["originator", "owner", "publisher", "pointOfContact"]
            end
          end
        end

        context "people" do
          it do
            before_save.people.should == []
          end
        end

        context "#valid?" do
          it do
            before_save.valid?.should == true
          end
        end
  
        
      end

    context "Saving dataset with data link" do
        
      context "roles" do
        it do
          dataset = Metadata::Dataset.new.before_save
          dataset.links << {rel: "data"}
          @request.body = dataset.to_json
          before_save.organisations.map {|o|o.roles}.flatten.should include("resourceProvider")
        end
        context "open data" do
          context "released is missing" do
            it "released (datestamp) from created (datestamp)" do
              dataset = Metadata::Dataset.new.before_save
              dataset.links << {rel: "data"}
              dataset.created = "1999-12-31T23:59:59Z"
              @request.body = dataset.to_json
              before_save.released.should == "1999-12-31T23:59:59Z"
            end
          end
          context "released is set to 9999-12-31" do
          it "released is unchanged (not set to published)" do
            dataset = Metadata::Dataset.new.before_save
            dataset.links << {rel: "data"}
            dataset.released = "9999-12-31T23:59:59Z"
            @request.body = dataset.to_json
            before_save.released.should == "9999-12-31T23:59:59Z"
          end
        end
        end

      end
    end

    context "licences" do
      context "when CC0" do
        it "other licences are removed" do
          dataset = Metadata::Dataset.new
          dataset.licences = ["http://creativecommons.org/publicdomain/zero/1.0/", "a", "b"]
          dataset = dataset.before_save
          dataset.licences.should == ["http://creativecommons.org/publicdomain/zero/1.0/"]
        end
      end
      context "when ÅVL" do
        it "other licences are removed" do
          dataset = Metadata::Dataset.new
          dataset.licences = ["http://www.lovdata.no/all/hl-19610512-002.html", "a", "b"]
          dataset = dataset.before_save
          dataset.licences.should == ["http://www.lovdata.no/all/hl-19610512-002.html"]
        end
      end
    end
  end



    context "Cleaning" do

      context "deduplicate_organisations" do
        context "3 x npolar.no" do

          o1 = Metadata::Dataset.npolar(["owner"])
          o2 = Metadata::Dataset.npolar(["publisher", "pointOfContact"])
          o3 = Metadata::Dataset.npolar(["resourceProvider"])
          dataset =  Metadata::Dataset.new({organisations: [o1, o2, o3]})
          dataset = dataset.deduplicate_organisations


          context "roles" do

            it do
              dataset.organisations.first.roles.should == ["owner", "publisher", "pointOfContact", "resourceProvider"] 
            end

            it do
              dataset.organisations.size.should == 1
            end
          end

          context "links" do
            it do
              dataset.organisations.first.links.size.should == 3
            end

          end
        end
      end



# links no duplicates
# no links to in org except for defined roles
      #context "XXX" do
      #  npi = {rel: "owner", href: "http://npolar.no", title: "Norwegian Polar Institute" }
      #  dataset = Metadata::Dataset.new({"links" => [o, o, o]}
      #
      #end

    end

  end
end
# rel == nil or "" => related