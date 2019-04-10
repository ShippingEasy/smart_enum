require 'spec_helper'
require 'smart_enum/yaml_store'

RSpec.describe SmartEnum::YamlStore do
  before(:each) do
    SmartEnum::YamlStore.data_root = File.join(File.dirname(__FILE__), "data")
  end

  describe 'register_values_from_file!' do
    it 'creates new values of the enum for each set of attributes defined in an inferred file name' do
      stub_const("Foo", Class.new(SmartEnum){
        attribute :id, Integer
        attribute :name, String
      })

      Foo.register_values_from_file!

      expect(Foo.values.length).to eq(3)
      expect(Foo[1].name).to eq("first")
      expect(Foo[2].name).to eq("second")
      expect(Foo[3].name).to eq("third")
    end

    it 'locks the enum' do
      stub_const("Foo", Class.new(SmartEnum){
        attribute :id, Integer
        attribute :name, String
      })
      expect(Foo.enum_locked?).to be_falsey

      Foo.register_values_from_file!
      Foo.values
      expect(Foo.enum_locked?).to be_truthy
    end

    it 'creates new values of the enum for each set of attributes defined in files in inferred directory' do
      stub_const("Bar", Class.new(SmartEnum){
        attribute :id, Integer
        attribute :name, String
      })

      Bar.register_values_from_file!

      expect(Bar.values.length).to eq(4)
      expect(Bar[1].name).to eq("first")
      expect(Bar[2].name).to eq("second")
      expect(Bar[3].name).to eq("third")
      expect(Bar[4].name).to eq("fourth")
    end

    it 'raises if both a file and directory match the inferred name, to avoid confusion' do
      stub_const("Wrong", Class.new(SmartEnum){
        attribute :id, Integer
        attribute :name, String
      })

      expect {
        Wrong.register_values_from_file!
      }.to raise_error(SmartEnum::YamlStore::AmbiguousSource, /Wrong/)
    end
  end
end
