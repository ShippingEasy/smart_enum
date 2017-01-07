require 'spec_helper'

RSpec.describe SmartEnum do
  context 'registration' do
    describe 'register_value' do
      it 'adds an instance to the values hash and does not lock' do
        model = Class.new(SmartEnum) do
          attribute :id, Integer
        end

        model.register_value({id: 99})
        expect(model.enum_locked?).to be_falsey
        model.lock_enum!
        expect(model.values.map(&:id)).to eq([99])
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
          parent.lock_enum!
          expect(parent[1].class).to eq(child1)
        end
      end
    end

    describe 'register_values' do
      it 'adds multiple instances to the values hash and locks it' do
        model = Class.new(SmartEnum) { attribute :id, Integer }
        model.register_values([{id: 77}, {'id'=> 88}]) # test symbolization while we're at it
        expect(model.values.map(&:id)).to match_array([77,88])
        expect(model.enum_locked?).to eq(true)
        expect(model[77]).to be_a(model)
        expect(model[88]).to be_a(model)
        expect(model[99]).to be_nil
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
          expect(model[1]).to be_a(model) # no type inference
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
            expect(model[1].class).to eq(SmartEnumTestChildClass)
            # Assert that value is findable from parent or child
            expect(SmartEnumTestChildClass[1].class).to eq(SmartEnumTestChildClass)

            expect(model[2].class).to eq(model)
            # Assert that parent classes aren't findable using child finders
            expect(SmartEnumTestChildClass[2]).to be_nil
          end
        end
      end
    end

    describe 'lock_enum' do
      it 'prevents further instances from being registered' do
        model = Class.new(SmartEnum) { attribute :id, Integer }
        model.lock_enum!
        expect(model.enum_locked?).to eq(true)
        expect{model.register_value(id: 1)}.to raise_error(SmartEnum::EnumLocked)
      end

      it 'freezes the underlying storage, protecting it from tampering' do
        model = Class.new(SmartEnum) { attribute :id, Integer }
        model.register_value(id: 1)
        model.lock_enum!
        expect{model.send(:_enum_storage)[1] = 'something else!'}.to raise_error("can't modify frozen Hash")
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

  context 'access' do
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

    it 'fails when model is not locked' do
      model = Class.new(SmartEnum) { attribute :id, Integer }
      expect{model[1]}.to raise_error("Cannot use unlocked enum")
      expect{model.values}.to raise_error("Cannot use unlocked enum")
    end

    it 'can access value by id' do
      expect(model[2]).to be_a(model)
      expect(model[2].name).to eq('B')
    end

    it 'returns nil for undefined id' do
      expect(model[99]).to be_nil
      expect(model['2']).to be_nil
    end

    it 'can return all values' do
      expect(model.values).to all(be_a(model))
      expect(model.values.map(&:id)).to match_array([1,2,3])
    end
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
          foo = Foo[1]
          bar = foo.bar
          expect(bar).to be_a(Bar)
          expect(bar).to eq(Bar[11])
        end

        it 'ignores nil association ids' do
          Bar.register_values([{id:11}, {id: 22}])
          Foo.register_values([{id:1, bar_id: nil}])
          foo = Foo[1]
          expect(foo.bar).to eq(nil)
        end

        it 'ignores nonexistent association ids' do
          Bar.register_values([{id:11}, {id: 22}])
          Foo.register_values([{id:1, bar_id: 33}])
          foo = Foo[1]
          expect(foo.bar).to eq(nil)
        end
      end

      describe 'generated writer method' do
        context 'when the foreign_key attribute is writable' do
          before do
            non_enum_class = Class.new do
              def self.name
                "NonEnumFoo"
              end
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

            bar = Bar[11]
            #instance.bar = bar
            #expect(instance.bar).to eq(bar)
            #expect(instance.bar_id).to eq(bar.id)
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
        foo = Foo[1]
        expect(foo.bar).to be_a(Baz)
        expect(foo.bar).to eq(Baz[11])
        expect(foo.bar).not_to eq(Bar[11])
      end

      it 'supports overriding the inferred foreign_key' do
        Foo.attribute :bar_id, Integer
        Foo.attribute :alternate_bar_id, Integer
        Foo.belongs_to_enum "bar", foreign_key: "alternate_bar_id"
        Foo.register_values([{id: 1, bar_id: 11, alternate_bar_id: 22}])
        Bar.register_values([{id: 11}, {id: 22}])
        foo = Foo[1]
        expect(foo.bar).to be_a(Bar)
        expect(foo.bar).to eq(Bar[22])
        expect(foo.bar).not_to eq(Bar[11])
      end

      it 'fails on unsupported arguments' do
        expect {
          Foo.belongs_to_enum "bar", some_unknown_option: true
        }.to raise_error(ArgumentError)
      end

      it 'registers a reflection' do
        Foo.belongs_to_enum 'bar'
        refl = Foo.enum_associations[:bar]
        expect(refl.association_name).to eq(:bar)
        expect(refl.foreign_key).to eq(:bar_id)
        expect(refl.association_class).to eq(Bar)
      end

      it 'can refer to a class that has not yet been defined' do
        Foo.attribute :created_later_id, Integer
        Foo.belongs_to_enum 'created_later'
        stub_const("CreatedLater", Class.new(SmartEnum) { attribute :id, Integer} )

        CreatedLater.register_values([{id:11}, {id: 22}])
        Foo.register_values([{id:1, created_later_id: 11}])

        foo = Foo[1]

        expect(foo.created_later).to be_an_instance_of(CreatedLater)
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
          bar = Bar[11]
          foos = bar.foos
          expect(foos.map(&:id)).to match_array([1,2])
          expect(foos).to all(be_a(Foo))

          expect(Bar[22].foos.map(&:id)).to match_array([3])
        end
      end

      it 'supports overriding the inferred class_name' do
        Foo.attribute :bar_id, Integer
        Bar.has_many_enums "bazs", class_name: "Foo"
        Foo.register_values([{id: 1, bar_id: 11}])
        Bar.register_values([{id: 11}])
        Baz.register_values([{id: 11}])
        bar = Bar[11]
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
        expect(Bar[11].foos.size).to eq(0)
        expect(Bar[22].foos.size).to eq(2)
      end

      it 'supports the :as option to override the association method name' do
        Foo.attribute :bar_id, Integer
        Bar.has_many_enums "foos", as: 'my_foos'
        Foo.register_values([{id: 1, bar_id: 11},
                             {id: 2, bar_id: 11}])
        Bar.register_values([{id: 11}])
        expect(Bar[11].my_foos.size).to eq(2)
      end

      it 'can refer to a class that has not yet been defined' do
        Foo.has_many_enums 'created_laters'
        stub_const("CreatedLater", Class.new(SmartEnum) {
          attribute :id, Integer
          attribute :foo_id, Integer
        })

        Foo.register_values([{id:1}])
        CreatedLater.register_values([{id:11, foo_id: 1}, {id: 22, foo_id: 1}])

        foo = Foo[1]

        expect(foo.created_laters.length).to eq(2)
      end
    end

    describe 'has_many_enums through' do
      describe 'generated association method' do
        before do
        end

        it 'locates associated instances (has_many -> has_many)' do
          Baz.attribute :foo_id, Integer
          Baz.belongs_to_enum :foo
          Bar.attribute :baz_id, Integer
          Bar.belongs_to_enum :baz
          Baz.has_many_enums :bars
          Foo.has_many_enums :bazs
          Foo.has_many_enums :bars, through: :bazs

          Foo.register_values([{id: 1}, {id: 2}])
          Baz.register_values([
            {id:1, foo_id: 1},
            {id:2, foo_id: 1},
            {id:3, foo_id: 2},
            {id:4, foo_id: 2},
            {id:5, foo_id: 2},
            {id:6, foo_id: 3},
          ])
          Bar.register_values([
            {id:10, baz_id: 1},
            {id:11, baz_id: 1},
            {id:20, baz_id: 2},
            {id:21, baz_id: 2},
            {id:22, baz_id: 2},
            {id:30, baz_id: 3},
            {id:31, baz_id: 3},
            {id:60, baz_id: 6},
          ])

          foo = Foo[1]
          bars = foo.bars

          expect(bars).to all(be_a(Bar))
          expect(bars.map(&:id)).to match_array([10, 11, 20, 21, 22])

          bars = Foo[2].bars
          expect(bars.map(&:id)).to match_array([30, 31])
        end

        it 'locates associated instances (has_many -> belongs_to) using source' do
          # baz is the join model between foo and bar
          Baz.attribute :foo_id, Integer
          Baz.attribute :bar_id, Integer
          Baz.belongs_to_enum :foo
          Baz.belongs_to_enum :bar
          Foo.has_many_enums :bazs
          Foo.has_many_enums :bars, through: :bazs, source: :bar

          Foo.register_values([{id: 1}, {id: 2}])
          Bar.register_values([{id: 1}, {id: 2}, {id: 3}, {id: 4}])

          Baz.register_values([
            {id:1, foo_id: 1, bar_id: 1},
            {id:2, foo_id: 1, bar_id: 4},
            {id:3, foo_id: 2, bar_id: 1},
            {id:4, foo_id: 2, bar_id: 2},
            {id:5, foo_id: 2, bar_id: 3},
            {id:6, foo_id: 3, bar_id: 3},
          ])

          foo = Foo[1]
          bars = foo.bars

          expect(bars).to all(be_a(Bar))
          expect(bars.map(&:id)).to match_array([1,4])

          bars = Foo[2].bars
          expect(bars.map(&:id)).to match_array([1,2,3])
        end
      end
    end

    describe 'has_one_enum' do
      describe 'generated association method' do
        before do
          Foo.attribute :bar_id, Integer
          Bar.has_one_enum :foo
        end

        it 'locates associated instance' do
          Bar.register_values([{id:11}, {id: 22}])
          Foo.register_values([{id:1, bar_id: 11}, {id: 2, bar_id: 12}, {id: 3, bar_id: 22}])
          bar = Bar[11]
          foo = bar.foo
          expect(foo.id).to eq(1)
          expect(foo).to be_a(Foo)

          expect(Bar[22].foo.id).to eq(3)
        end
      end

      it 'supports overriding the inferred class_name' do
        Foo.attribute :bar_id, Integer
        Bar.has_one_enum "baz", class_name: "Foo"
        Foo.register_values([{id: 1, bar_id: 11}])
        Bar.register_values([{id: 11}])
        Baz.register_values([{id: 11}])
        bar = Bar[11]
        expect(bar.baz).to be_a(Foo)
        expect(bar.baz.id).to eq(1)
      end

      it 'supports overriding the inferred foreign_key' do
        Foo.attribute :bar_id, Integer
        Foo.attribute :alternate_bar_id, Integer
        Bar.has_one_enum "foo", foreign_key: 'alternate_bar_id'
        Foo.register_values([{id: 1, bar_id: 22, alternate_bar_id: 11},
                             {id: 2, bar_id: 11, alternate_bar_id: 22}])
        Bar.register_values([{id: 11},{id: 22}])
        expect(Bar[11].foo.id).to eq(1)
        expect(Bar[22].foo.id).to eq(2)
      end

      it 'can refer to a class that has not yet been defined' do
        Foo.has_one_enum 'created_later'
        stub_const("CreatedLater", Class.new(SmartEnum) {
          attribute :id, Integer
          attribute :foo_id, Integer
        })

        Foo.register_values([{id:1}])
        CreatedLater.register_values([{id:11, foo_id: 1}, {id: 22, foo_id: 2}])

        foo = Foo[1]

        expect(foo.created_later.id).to eq(11)
      end
    end

    describe 'has_one_enum through' do
      describe 'generated association method' do
        it 'locates associated instance' do
          Bar.attribute :foo_id, Integer
          Bar.attribute :baz_id, Integer
          Bar.belongs_to_enum :foo
          Bar.belongs_to_enum :baz
          Foo.has_one_enum :bar
          Foo.has_one_enum :baz, through: :bar

          Foo.register_values([{id:1}, {id: 2}, {id: 3}])
          Baz.register_values([{id: 31},{id: 32}])
          Bar.register_values([{id:11, foo_id: 1, baz_id: 31}, {id: 22, foo_id: 2, baz_id: 32}])

          foo = Foo[1]
          expect(foo.baz).to be_a(Baz)
          expect(foo.baz.id).to eq(31)

          foo = Foo[2]
          expect(foo.baz).to be_a(Baz)
          expect(foo.baz.id).to eq(32)
        end
      end

      it 'supports overriding the source' do
          Bar.attribute :foo_id, Integer
          Bar.attribute :baz_id, Integer
          Bar.belongs_to_enum :foo
          Bar.belongs_to_enum :secret, class_name: "Baz", foreign_key: :baz_id
          Foo.has_one_enum :bar
          Foo.has_one_enum :baz, through: :bar, source: :secret

          Foo.register_values([{id:1}, {id: 2}, {id: 3}])
          Baz.register_values([{id: 31},{id: 32}])
          Bar.register_values([{id:11, foo_id: 1, baz_id: 31}, {id: 22, foo_id: 2, baz_id: 32}])

          foo = Foo[1]
          expect(foo.baz).to be_a(Baz)
          expect(foo.baz.id).to eq(31)

          foo = Foo[2]
          expect(foo.baz).to be_a(Baz)
          expect(foo.baz.id).to eq(32)
      end
    end
  end
end
