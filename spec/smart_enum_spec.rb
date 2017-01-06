require 'spec_helper'

RSpec.describe SmartEnum do
  context 'registration' do
    describe 'register_value' do
      it 'adds an instance to the values hash and does not lock' do
        model = Class.new(SmartEnum) do
          attribute :id, Integer
        end

        model.register_value({id: 99})
        expect(model.enum_values.keys).to eq([99])
        expect(model.enum_locked?).to be_falsey
      end

      it 'requires an :id key to build the primary index' do
        model = Class.new(SmartEnum) do
          attribute :id, Integer
          attribute :name, String
        end
        expect{model.register_value(name: "Blah")}.to raise_error('Must provide id')
      end

      it 'fails for duplicate values' do
        model = Class.new(SmartEnum) { attribute :id, Integer }
        expect{model.register_value(id: 1)}.not_to raise_error
        expect{model.register_value(id: 1)}.to raise_error(/Already registered id 1!/)
      end

      describe 'descendant class registration' do
        it 'accepts the :enum_type option, but validates ancestorship' do
          parent = Class.new(SmartEnum) { attribute :id, Integer }
          child1 = Class.new(parent)
          child2 = Class.new(parent)
          parent.register_value(id: 1, enum_type: child1)
          expect{child1.register_value(id: 2, enum_type: parent)}.to raise_error(
            /Specified class .* must derive from .*/
          )
          expect{child2.register_value(id: 2, enum_type: child1)}.to raise_error(
            /Specified class .* must derive from .*/
          )
          # it works this way though
          expect(parent.enum_values.keys).to eq([1])
          parent.lock_enum!
          expect(parent.find(1).class).to eq(child1)
        end
      end
    end

    describe 'register_values' do
      it 'adds multiple instances to the values hash and locks it' do
        model = Class.new(SmartEnum) { attribute :id, Integer }
        model.register_values([{id: 77}, {'id'=> 88}]) # test symbolization while we're at it
        expect(model.enum_values.keys).to match_array([77,88])
        expect(model.enum_locked?).to eq(true)
        expect(model.find(77)).to be_a(model)
        expect(model.find(88)).to be_a(model)
        expect{model.find(99)}.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'prevents dupe registration' do
        model = Class.new(SmartEnum) { attribute :id, Integer }
        expect{
          model.register_values([{id: 99},{id: 88}, {id: 99}])
        }.to raise_error("Already registered id 99!")
      end

      context 'type inference' do
        it 'does nothing if not enabled' do
          model = Class.new(SmartEnum) do
            attribute :id, Integer
            attribute :type, String
          end

          model.register_values([{id: 1, type: 'SomeNonexistentClass'}])
          expect(model.find(1)).to be_a(model) # no type inference
        end

        context 'it tries to constantize types if asked' do
          it 'blows up if the type is undefined' do
            model = Class.new(SmartEnum) do
              attribute :id, Integer
              attribute :type, String
            end

            expect{
              model.register_values([{id: 1, type: 'SomeNonExistentClass'}], detect_sti_types: true)
            }.to raise_error(NameError, "uninitialized constant SomeNonExistentClass")
          end

          it "blows up if the type doesn't descend from root" do
            model = Class.new(SmartEnum) do
              attribute :id, Integer
              attribute :type, String
            end

            SmartEnumTestUnrelatedClass = Class.new(SmartEnum) do
              attribute :id, Integer
              attribute :type, String
            end

            expect {
              model.register_values([
                {id: 1, type: 'SmartEnumTestUnrelatedClass'},
              ], detect_sti_types: true)
            }.to raise_error(
              /Specified class SmartEnumTestUnrelatedClass must derive from #<Class/
            )
          end

          it 'succeeds if the type is defined' do
            model = Class.new(SmartEnum) do
              attribute :id, Integer
              attribute :type, String
            end

            SmartEnumTestChildClass = Class.new(model)
            model.register_values([
              {id: 1, type: 'SmartEnumTestChildClass'},
              {id: 2}
            ], detect_sti_types: true)
            expect(model.find(1).class).to eq(SmartEnumTestChildClass)
            # Assert that value is findable from parent or child
            expect(SmartEnumTestChildClass.find(1).class).to eq(SmartEnumTestChildClass)

            expect(model.find(2).class).to eq(model)
            # Assert that parent classes aren't findable using child finders
            expect{SmartEnumTestChildClass.find(2)}.to raise_error(ActiveRecord::RecordNotFound)
          end

        end
      end
    end


    describe 'lock_enum' do
      it 'prevents further instances from being registered' do
        model = Class.new(SmartEnum) { attribute :id, Integer }
        model.lock_enum!
        expect(model.enum_locked?).to eq(true)
        expect{model.register_value(id: 1)}.to raise_error(SmartEnum::Registration::EnumLocked)
      end

      it 'freezes the underlying storage, protecting it from tampering' do
        model = Class.new(SmartEnum) { attribute :id, Integer }
        model.register_value(id: 1)
        model.lock_enum!
        expect{model.enum_values[1] = 'something else!'}.to raise_error("can't modify frozen Hash")
      end

      it 'locks all descendant classes' do
        parent = Class.new(SmartEnum) { attribute :id, Integer }
        child = Class.new(parent)
        parent.lock_enum!
        expect(parent.enum_locked?).to eq(true)
        expect(child.enum_locked?).to eq(true)
      end

      it 'locks descendant classes that are defined after locking' do
        pending "not implemented yet"
        parent = Class.new(SmartEnum) { attribute :id, Integer }
        parent.lock_enum!
        child = Class.new(parent)
        expect(parent.enum_locked?).to eq(true)
        expect(child.enum_locked?).to eq(true)
      end
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
        specify do
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
            let(:target) { str_model.enum_values.values.first }

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
            let(:target) { weird_model.enum_values.values.first }

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
            let(:target) { sym_model.enum_values.values.first }

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

  context 'ActiveRecord interop' do
  end

  context 'association' do
    before do
      stub_const("Foo", Class.new(SmartEnum) { attribute :id, Integer} )
      stub_const("Bar", Class.new(SmartEnum) { attribute :id, Integer} )
      stub_const("Baz", Class.new(SmartEnum) { attribute :id, Integer} )
    end

    describe 'belongs_to_enum' do
      describe 'generated reader method' do
        before do
          Foo.attribute :bar_id, Integer
          Foo.belongs_to_enum "bar"
        end

        it 'locates associated instances' do
          Bar.register_values([{id:11}, {id: 22}])
          Foo.register_values([{id:1, bar_id: 11}])
          foo = Foo.find(1)
          bar = foo.bar
          expect(bar).to be_a(Bar)
          expect(bar).to eq(Bar.find(11))
        end

        it 'ignores nil association ids' do
          Bar.register_values([{id:11}, {id: 22}])
          Foo.register_values([{id:1, bar_id: nil}])
          foo = Foo.find(1)
          expect(foo.bar).to eq(nil)
        end

        it 'ignores nonexistent association ids' do
          Bar.register_values([{id:11}, {id: 22}])
          Foo.register_values([{id:1, bar_id: 33}])
          foo = Foo.find(1)
          expect(foo.bar).to eq(nil)
        end
      end

      describe 'generated writer method' do
        context 'when the foreign_key attribute is writable' do
          before do
            non_enum_class = Class.new do
              extend SmartEnum::Associations
              attr_accessor :id, :bar_id
              belongs_to_enum "bar"
            end
            stub_const("NonEnumFoo", non_enum_class)
          end

          it 'includes an association writer to set the foreign_key' do
            Bar.register_values([{id:11}, {id: 22}])

            instance = NonEnumFoo.new
            expect(instance).to respond_to(:bar=)

            bar = Bar.find(11)
            instance.bar = bar
            expect(instance.bar).to eq(bar)
            expect(instance.bar_id).to eq(bar.id)
          end
        end

        context 'when the foreign_key attribute is not writable' do
          it 'does not generate a writer method' do
            expect(Foo.new).to_not respond_to(:bar=)
          end
        end

      end

      it 'supports overriding the inferred class_name' do
        Foo.attribute :bar_id, Integer
        Foo.belongs_to_enum "bar", class_name: "Baz"
        Foo.register_values([{id: 1, bar_id: 11}])
        Bar.register_values([{id: 11}])
        Baz.register_values([{id: 11}])
        foo = Foo.find(1)
        expect(foo.bar).to be_a(Baz)
        expect(foo.bar).to eq(Baz.find(11))
        expect(foo.bar).not_to eq(Bar.find(11))
      end

      it 'supports overriding the inferred foreign_key' do
        Foo.attribute :bar_id, Integer
        Foo.attribute :alternate_bar_id, Integer
        Foo.belongs_to_enum "bar", foreign_key: "alternate_bar_id"
        Foo.register_values([{id: 1, bar_id: 11, alternate_bar_id: 22}])
        Bar.register_values([{id: 11}, {id: 22}])
        foo = Foo.find(1)
        expect(foo.bar).to be_a(Bar)
        expect(foo.bar).to eq(Bar.find(22))
        expect(foo.bar).not_to eq(Bar.find(11))
      end

      it 'fails on unsupported arguments' do
        expect {
          Foo.belongs_to_enum "bar", some_unknown_option: true
        }.to raise_error("unsupported options: some_unknown_option")
      end

      it 'registers a reflection' do
        Foo.belongs_to_enum 'bar'
        refl = Foo.enum_associations[:bar]
        expect(refl.association_name).to eq(:bar)
        expect(refl.foreign_key).to eq(:bar_id)
        expect(refl.association_class).to eq(Bar)
      end
    end

    describe 'has_many_enums' do
      describe 'generated association method' do
        before do
          Foo.attribute :bar_id, Integer
          Bar.has_many_enums :foos
        end

        it 'locates associated instances' do
          Bar.register_values([{id:11}, {id: 22}])
          Foo.register_values([{id:1, bar_id: 11}, {id: 2, bar_id: 11}, {id: 3, bar_id: 22}])
          bar = Bar.find(11)
          foos = bar.foos
          expect(foos.map(&:id)).to match_array([1,2])
          expect(foos).to all(be_a(Foo))

          expect(Bar.find(22).foos.map(&:id)).to match_array([3])
        end
      end

      it 'supports overriding the inferred class_name' do
        Foo.attribute :bar_id, Integer
        Bar.has_many_enums "bazs", class_name: "Foo"
        Foo.register_values([{id: 1, bar_id: 11}])
        Bar.register_values([{id: 11}])
        Baz.register_values([{id: 11}])
        bar = Bar.find(11)
        expect(bar.bazs).to all(be_a(Foo))
        expect(bar.bazs.map(&:id)).to eq([1])
      end

      it 'supports overriding the inferred foreign_key' do
        Foo.attribute :bar_id, Integer
        Foo.attribute :alternate_bar_id, Integer
        Bar.has_many_enums "foos", foreign_key: 'alternate_bar_id'
        Foo.register_values([{id: 1, bar_id: 11, alternate_bar_id: 22},
                             {id: 2, bar_id: 11, alternate_bar_id: 22}])
        Bar.register_values([{id: 11},{id: 22}])
        expect(Bar.find(11).foos.size).to eq(0)
        expect(Bar.find(22).foos.size).to eq(2)
      end

      it 'supports the :as option to override the association method name' do
        Foo.attribute :bar_id, Integer
        Bar.has_many_enums "foos", as: 'my_foos'
        Foo.register_values([{id: 1, bar_id: 11},
                             {id: 2, bar_id: 11}])
        Bar.register_values([{id: 11}])
        expect(Bar.find(11).my_foos.size).to eq(2)
      end
    end
  end

  context 'monetize' do
    let(:model) {
      Class.new(SmartEnum) do
        attribute :cost_cents, Integer
        monetize :cost_cents
      end
    }

    it 'supports a limited version of the AR monetize macro' do
      instance = model.new(cost_cents: 1000)
      expect(instance.cost).to eq(Money.new(1000))
    end

    it 'validates that the attribute exists' do
      expect { model.class_eval{ monetize :cost } }.to raise_error(
        "no attribute called cost, (Do you need to add '_cents'?)"
      )
    end

    it 'validates that the attribute is typed correctly' do
      expect {
        model.class_eval {
          attribute :blah_cents, String
          monetize :blah_cents      
        }
      }.to raise_error(
        "attribute :blah_cents can't monetize, only Integer is allowed"
      )
    end
  end
end
