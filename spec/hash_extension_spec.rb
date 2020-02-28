require 'spec_helper'

RSpec.describe HashExtensions do
  before(:each) do
    @h = { "a" => "b", "b" => { "c" => "d" }}
  end

  context "get" do
    context "string" do
      it "should get value for known key" do
        expect(@h.get("a")).to eq('b')
      end

      it "should get value from nested key" do
        expect(@h.get("b.c")).to eq('d')
      end

      it "should get nil for unkown key" do
        expect(@h.get("unknown")).to eq(nil)
      end
    end

    context "array" do
      it "should get value for known key" do
        expect(@h.get(%w(a))).to eq('b')
      end

      it "should get value from nested key" do
        expect(@h.get(%w(b c))).to eq('d')
      end

      it "should get nil for unkown key" do
        expect(@h.get(%w(unknown))).to eq(nil)
      end
    end
  end

  context "set" do
    context "string" do
      it "should set a new value" do
        expect(@h.set("a", "new_value")).to eq("new_value")
      end

      it "should set a nested value" do
        expect(@h.set("b.c", "new_value")).to eq("new_value")
      end

      it "should not overwrite a value" do
        expect(@h.set("b.c", "new_value",false)).to eq("d")
      end

      it "should set nil" do
        expect(@h.set("b.c", nil)).to eq(nil)
      end
    end

    context "array" do
      it "should set a new value" do
        expect(@h.set(%w(a), "new_value")).to eq("new_value")
      end

      it "should set a nested value" do
        expect(@h.set(%w(b c), "new_value")).to eq("new_value")
      end

      it "should not overwrite a value" do
        expect(@h.set(%w(b c), "new_value",false)).to eq("d")
      end

      it "should set nil" do
        expect(@h.set(%w(b c),nil)).to eq(nil)
      end
    end
  end

  context "all_keys_with_path" do
    it "should get all key paths in an array" do
      expect(@h.all_keys_with_path).to eq(['a','b.c'])
    end

    it "should get an empy array if empty hash was passed" do
      expect({}.all_keys_with_path.is_a?(Array)).to eq(true)
      expect({}.all_keys_with_path.size).to eq(0)
    end
  end
end
