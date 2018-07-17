require 'spec_helper'

RSpec.describe SmartEnum::Utilities do
  describe '.symbolize_hash_keys' do
    subject(:symbolized) { ->input { SmartEnum::Utilities.symbolize_hash_keys(input) } }
    it 'changes root keys from strings to symbols' do
      input = { "foo" => "bar", "baz" => "qux" }
      expect(symbolized.(input)).to eq(foo: "bar", baz: "qux")
    end

    it 'it saves allocations by returning the same object if all keys are already symbols' do
      input = { :foo => "bar", :baz => "qux" }
      expect(symbolized.(input).object_id).to eq(input.object_id)
    end
  end

  describe '.foreign_key' do
    subject(:foreign_key) { ->input { SmartEnum::Utilities.foreign_key(input) } }

    it 'converts camelcase strings to foreign-key-style' do
      expect(foreign_key.('MyClassName')).to eq('my_class_name_id')
    end

    it 'converts snake case strings to foreign-key-style' do
      expect(foreign_key.('some_thing')).to eq('some_thing_id')
    end
  end

  describe '.singularize' do
    subject(:singularize) { ->input { SmartEnum::Utilities.singularize(input) } }

    it 'strips an s from strings' do
      expect(singularize.('widgets')).to eq('widget')
    end

    it 'does nothing with no s' do
      expect(singularize.('widget')).to eq('widget')
    end
  end

  describe '.tableize' do
    subject(:tableize) { ->input { SmartEnum::Utilities.tableize(input) } }

    it 'converts singular camelcase strings to the equivalent table name' do
      expect(tableize.('FooBar')).to eq('foo_bars')
    end

    it 'converts singular underscore strings to the equivalent table name' do
      expect(tableize.('baz_bar')).to eq('baz_bars')
    end
  end

  describe '.classify' do
    subject(:classify) { ->input { SmartEnum::Utilities.classify(input) } }

    it 'converts table-style strings to camelcase class-style' do
      expect(classify.('some_things')).to eq('SomeThing')
    end

    it 'converts singular underscore strings to camelcase class-style' do
      expect(classify.('foo_bar')).to eq('FooBar')
    end
  end

  describe '.camelize' do
    subject(:camelize) { ->input { SmartEnum::Utilities.camelize(input) } }

    it 'converts underscore text to camelcase' do
      expect(camelize.('some_things')).to eq('SomeThings')
    end
  end

  describe '.underscore' do
    subject(:underscore) { ->input { SmartEnum::Utilities.underscore(input) } }

    it 'converts to underscore' do
      expect(underscore.('FooModule::BarClass')).to eq('foo_module/bar_class')
    end
  end
end
