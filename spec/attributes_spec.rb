require 'spec_helper'

RSpec.describe SmartEnum::Attributes do
  let(:simple_model) do
    Class.new do
      include SmartEnum::Attributes
      attribute :id, Integer
      attribute :name, String
    end
  end

  it "provides a useful .inspect" do
    stub_const("Foo", simple_model)
    expect(simple_model.inspect).to eq("Foo(UNLOCKED id: Integer, name: String)")
  end

  it "provides a useful #inspect" do
    stub_const("Foo", simple_model)
    instance = Foo.new(id: 3, name: "John")
    expect(instance.inspect).to eq('#<Foo id: 3, name: "John">')
  end

  describe 'initializer' do
    it 'forces you to have at least one attribute' do
      EmptyModel = Class.new { include SmartEnum::Attributes }
      expect{EmptyModel.new}.to raise_error(/no attributes defined for EmptyModel/)
    end

    it 'initializes from arguments hash' do
      instance = simple_model.new(id: 1, name: 'foo')
      expect(instance.attributes).to eq({id: 1, name: 'foo'})
    end

    it 'defaults values to nil' do
      instance = simple_model.new
      expect(instance.attributes).to eq({id: nil, name: nil})
    end

    it 'refuses unknown arguments' do
      expect{simple_model.new(blah: 123)}.to raise_error("unrecognized options: {:blah=>123}")
    end

    describe 'type specifiers' do
      it 'asserts that types are as specified' do
        expect{simple_model.new(name: Time.now)}.to raise_error(
          /Attribute :name passed .*:Time in initializer, but needs \[String\] and has no coercer/
        )
      end

      it 'supports composite type specifiers' do
        model = Class.new do
          include SmartEnum::Attributes
          attribute :foo, [String, Integer]
        end
        expect(model.new(foo: 5).foo).to eq(5)
        expect(model.new(foo: '5').foo).to eq('5')
        expect{model.new(foo: Object.new)}.to raise_error(
          /Attribute :foo passed .*:Object in initializer, but needs \[String, Integer\] and has no coercer/
        )
      end
    end

    describe 'type coercion' do
      it 'supports coercion for nonmatching types' do
        model = Class.new do
          include SmartEnum::Attributes
          attribute :foo, String, coercer: ->(obj) { obj.class.name }
        end
        expect(model.new(foo: '5').foo).to eq('5') # no coercion needed
        expect(model.new(foo: Object.new).foo).to eq('Object')
      end

      it 'enforces that coercers emit objects matching type specifiers' do
        model = Class.new do
          include SmartEnum::Attributes
          attribute :foo, String, coercer: ->(obj) { 100 }
        end
        expect{model.new(foo: Object.new)}.to raise_error(
          /coercer for foo failed to coerce .* to one of \[String\].  Got 100:Fixnum instead/
        )
      end

      it 'provides boolean alias supporting predicates and nil coercion' do
        class BooleanModel # Class.new{} syntax can't resolve Boolean constant correctly
          include SmartEnum::Attributes
          attribute :enabled, Boolean
        end
        expect(BooleanModel.new(enabled: true).enabled).to eq(true)
        expect(BooleanModel.new(enabled: false).enabled).to eq(false)
        expect(BooleanModel.new(enabled: nil).enabled).to eq(false)
        expect(BooleanModel.new(enabled: true).enabled?).to eq(true)
        expect(BooleanModel.new(enabled: false).enabled?).to eq(false)
        expect(BooleanModel.new(enabled: nil).enabled?).to eq(false)

        # assert that coercion is only automatic for nil, coercer required for everything else
        expect{BooleanModel.new(enabled: 'blah')}.to raise_error(
          "Attribute :enabled passed blah:String in initializer, but needs [TrueClass, FalseClass] and has no coercer"
        )
      end
    end
  end

  describe 'attribute_set' do
    it 'allows introspection of defined attributes' do
      attribute_set = simple_model.attribute_set
      expect(attribute_set).to be_a(Hash)
      expect(attribute_set[:id]).to be_a(SmartEnum::Attributes::Attribute)
      expect(attribute_set[:id].types).to eq([Integer])
      expect(attribute_set[:id].name).to eq(:id)
      expect(attribute_set[:id].coercer).to eq(nil)
      expect(attribute_set[:name]).to be_a(SmartEnum::Attributes::Attribute)
      expect(attribute_set[:name].types).to eq([String])
      expect(attribute_set[:name].name).to eq(:name)
      expect(attribute_set[:name].coercer).to eq(nil)
    end

    it 'child classes inherit parent class attribute sets' do
      parent = simple_model
      child = Class.new(parent) do
        attribute :child_only_attribute, Integer
      end
      expect(parent.attribute_set.keys).to match_array([:id, :name])
      expect(child.attribute_set.keys).to match_array([:id, :name, :child_only_attribute])
    end
  end
end
