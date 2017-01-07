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
      expect(Foo.enum_locked?).to be_truthy
    end
  end
end

