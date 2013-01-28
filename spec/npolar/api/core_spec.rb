require "spec_helper"
require "npolar/api/core.rb"

describe Npolar::Api::Core do
  before :each do
    @core = Npolar::Api::Core.new()
  end

  context "#force_array" do
    it "when passed string 'foo' we expect ['foo']" do
      @core.send(:force_array, 'foo').should == ['foo']
    end

    it "when passed a callable with arg 'foo' we expect it to be called and return 'foobar'" do
      @core.send(:force_array, lambda{|x| x+'bar'}, 'foo').should == 'foobar'
    end

    it "when passed Array [1, 2, 3, 4] we expect [1, 2, 3, 4]" do
      @core.send(:force_array, [1, 2, 3, 4]).should == [1, 2, 3, 4]
    end

    it "when passed something else, like nil, we expect []" do
      @core.send(:force_array, nil).should == []
    end

  end
end
