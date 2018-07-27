require 'spec_helper'
require 'smart_enum/active_record_compatibility'

RSpec.describe SmartEnum::ActiveRecordCompatibility do
  it "behaves like a serializable ActiveModel" do
    model = Class.new(SmartEnum) {
      attribute :id, Integer
      attribute :name, String
    }
    instance = model.new({id: 1, name: "Tony"})
    expect(instance.serializable_hash).to eq({id: 1, name: "Tony"})
  end

  describe "naming" do
    around do |example|
      FakeSmartModel = Class.new(SmartEnum) {
        attribute :id, Integer
        attribute :name, String
      }

      example.run

      Object.send(:remove_const, "FakeSmartModel")
      expect(defined?(FakeSmartModel)).to be_falsey
    end

    it "reports its model name like an ActiveRecord instance" do
      instance = FakeSmartModel.new({id: 1, name: "Tony"})

      expect(instance.model_name.name).to eq("FakeSmartModel")
    end

    it "reports its param_key like an ActiveRecord instance" do
      instance = FakeSmartModel.new({id: 3, name: "Tony"})

      expect(instance.model_name.param_key).to eq("fake_smart_model")
    end
  end

  describe 'base_class' do
    it 'determines the root of an inheritence tree' do
      parent = Class.new(SmartEnum)
      child = Class.new(parent)
      deep_child = Class.new(child)
      expect(parent.base_class).to eq(parent)
      expect(child.base_class).to eq(parent)
      expect(deep_child.base_class).to eq(parent)
    end
  end

  context 'querying' do
    it 'fails when model is not locked' do
      model = Class.new(SmartEnum) { attribute :id, Integer }
      expect{model.find(1)}.to raise_error("Cannot use unlocked enum")
      expect{model.find_by(id: 1)}.to raise_error("Cannot use unlocked enum")
      expect{model.find_by!(id: 1)}.to raise_error("Cannot use unlocked enum")
      expect{model.where(id: 1)}.to raise_error("Cannot use unlocked enum")
    end

    context 'when locked and populated' do
      let(:model) do
        Class.new(SmartEnum) do
          attribute :id, Integer
          attribute :name, String
          attribute :enabled, SmartEnum::Boolean
        end
      end

      before do
        model.register_values([
          {id: 1, name: 'A', enabled: true},
          {id: 2, name: 'B', enabled: true},
          {id: 3, name: 'C', enabled: false}
        ])
      end

      describe 'where' do
        it 'returns all enum values that match the given attribute values' do
          result = model.where(id: 1)
          expect(result.size).to eq(1)
          expect(result[0].attributes).to eq(id: 1, name: 'A', enabled: true)

          result = model.where(enabled: true)
          expect(result.size).to eq(2)
        end
      end

      describe 'find_by' do
        it 'finds by attributes' do
          result = model.find_by(id: 1)
          expect(result).to be_a(model)
          expect(result.name).to eq('A')
          expect(result).to be_enabled
        end

        it 'returns nil when unmatched' do
          result = model.find_by(id: 9)
          expect(result).to eq(nil)
        end
      end

      describe 'first' do
        it 'finds the first attribute' do
          result = model.first
          expect(result.name).to eq "A"
        end

        it 'can grab the first N elements' do
          results = model.first(2)
          expect(results.first.name).to eq "A"
          expect(results.last.name).to eq "B"
        end
      end

      describe 'last' do
        it 'finds the last attribute' do
          result = model.last
          expect(result.name).to eq "C"
        end

        it 'can grab the last N elements' do
          results = model.last(2)
          expect(results.first.name).to eq "B"
          expect(results.last.name).to eq "C"
        end
      end

      describe 'count' do
        it 'returns the count of objects' do
          count = model.count
          expect(count).to eq(3)
        end
      end

      describe 'find' do
        it 'finds using PK only' do
          result = model.find(1)
          expect(result).to be_a(model)
        end

        it 'raises on failure' do
          expect { model.find(9999) }
            .to raise_error(ActiveRecord::RecordNotFound, /Couldn't find.*with 'id'=9999/)
        end

        describe 'PK typecasting' do
          context 'with integer pk' do
            it 'supports querying by stringified integer' do
              expect(model.find('1')).to eq(model.find(1))
            end

            it 'fails when querying by uncastable type' do
              expect{model.find(Object.new)}.to raise_error(TypeError, "can't convert Object into Integer")
            end
          end

          context 'with string pk' do
            let(:str_model) { Class.new(SmartEnum) { attribute :id, String } }
            before { str_model.register_values([{id: "first_one"}]) }
            let(:target) { str_model.values.first }

            it 'supports querying by string' do
              expect(str_model.find('first_one')).to eq(target)
            end

            it 'supports querying by symbol' do
              expect(str_model.find(:first_one)).to eq(target)
            end
          end

          context 'with a weird PK' do
            let(:weird_model) { Class.new(SmartEnum) { attribute :id, Object} }
            let(:obj_id) { Object.new }
            before { weird_model.register_values([{id: obj_id}]) }
            let(:target) { weird_model.values.first }

            it 'supports querying by the actual id type' do
              expect(weird_model.find(obj_id)).to eq(target)
            end

            it 'fails when trying to query with another type' do
              expect{weird_model.find('something')}.to raise_error 'incompatible type: got String, need [Object] or something castable to that'
            end
          end

          context 'with symbol pk' do
            let(:sym_model) { Class.new(SmartEnum) { attribute :id, Symbol } }
            before { sym_model.register_values([{id: :first_one}]) }
            let(:target) { sym_model.values.first }

            it 'supports querying by string' do
              expect(sym_model.find('first_one')).to eq(target)
            end

            it 'supports querying by symbol' do
              expect(sym_model.find(:first_one)).to eq(target)
            end
          end
        end
      end

      describe 'find_by!' do
        it 'acts like find_by when results are available' do
          expect(model.find_by!(id: 1)).to eq(model.find_by(id: 1))
        end

        it 'raises when the result is not available' do
          expect { model.find_by!(id: 999) }
            .to raise_error(ActiveRecord::RecordNotFound, /Couldn't find.*with {:id=>999}/)
        end
      end

      describe 'query type-casting' do
        it 'casts compatible types as necessary' do
          expect(model.find_by(id: '1').id).to eq(1)
        end

        it 'hard-fails for uncastable types' do
          expect{model.find_by(id: 'aa')}
            .to raise_error(ArgumentError, 'invalid value for Integer(): "aa"')
        end

        it 'casts booleans using truthiness, *not* 1/0/t/f/etc' do
          expect(model.find_by(enabled: '0')).to be_enabled
          expect(model.find_by(enabled: 0)).to be_enabled
          expect(model.find_by(enabled: 'f')).to be_enabled

          # the below are the only boolean values that should return false results
          expect(model.find_by(enabled: false)).not_to be_enabled
          expect(model.find_by(enabled: nil)).not_to be_enabled
        end

        it 'allows nil types' do
          expect(model.find_by(id: nil)).to eq(nil)
        end
      end
    end
  end
end
