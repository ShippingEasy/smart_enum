# frozen_string_literal: true

# A simple replacement for Virtus.
# - Objects are currently readonly once initialized.
# - Initialization args either match their type annotation or are nil.
# - Explicit coercion is supported with the :coercer option.
# - Booleans have special handling, they get predicate methods and get
#   automatic nil => false casting.
# - Child classes automatically inherit parents' attribute set.
#
# Example:
#
#   class Foo
#     include SmartEnum::Attributes
#     attribute :id, Integer
#     attribute :enabled, Boolean
#     attribute :created_at, Time, coercer: ->(arg) { Time.parse(arg) }
#   end
#
#   Foo.new(id: 1, created_at: '2016-1-1')
#   # => #<Foo:0x007f970a090760 @attributes={:id=>1, :created_at=>"2016-01-01T00:00:00.000-06:00", :enabled=>false}}>
#   Foo.new(id: 1, created_at: 123)
#   # TypeError: no implicit conversion of 123 into String
#   Foo.new(id: 1, enabled: true).enabled?
#   # => true
#
class SmartEnum
  module Attributes
    Boolean = [TrueClass, FalseClass].freeze

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def attribute_set
        @attribute_set ||= {}
      end

      def inherited(child_class)
        # STI children should start with an attribute set cloned from their parent.
        # Otherwise theirs will start blank.
        child_class.instance_variable_set(:@attribute_set, self.attribute_set.dup)
        # STI children must *share* a reference to the same init_mutex as their
        # parent so that reads are correctly blocked during async loading.
        child_class.instance_variable_set(:@_init_mutex, @_init_mutex)
      end

      def attribute(name, types, coercer: nil, reader_method: nil)
        name = name.to_sym
        types = Array.wrap(types)
        attribute_set[name] = Attribute.new(name, types, coercer)
        define_method(reader_method || name) do
          attributes[name]
        end
        if types == Boolean
          alias_method "#{name}?".to_sym, name
        end
      end

      def inspect
        lock_str = @enum_locked ? "LOCKED" : "UNLOCKED"
        "#{self}(#{lock_str} #{attribute_set.values.map(&:inspect).join(", ")})"
      end
    end

    def attributes
      @attributes ||= {}
    end

    def initialize(opts={})
      if block_given?
        fail "Block passed, but it would be ignored"
      end
      init_opts = opts.symbolize_keys
      if self.class.attribute_set.empty?
        fail "no attributes defined for #{self.class}"
      end
      self.class.attribute_set.each do |attr_name, attr_def|
        if (arg=init_opts.delete(attr_name))
          if attr_def.types.any?{|type| arg.is_a?(type) }
            # No coercion necessary
            attributes[attr_name] = arg
          elsif attr_def.coercer
            coerced_arg = attr_def.coercer.call(arg)
            if attr_def.types.none?{|type| coerced_arg.is_a?(type) }
              # Coercer didn't give correct type
              fail "coercer for #{attr_name} failed to coerce #{arg} to one of #{attr_def.types.inspect}.  Got #{coerced_arg}:#{coerced_arg.class} instead"
            end
            # Coercer worked
            attributes[attr_name] = coerced_arg
          else
            # Wrong type, no coercer passed
            fail "Attribute :#{attr_name} passed #{arg}:#{arg.class} in initializer, but needs #{attr_def.types.inspect} and has no coercer"
          end
        else
          if attr_def.types == Boolean
            # booleans should always be true or false, not nil
            attributes[attr_name] = false
          else
            # Nothing provided for this attr in init opts, set to nil
            # to make sure we always have a complete attributes hash.
            attributes[attr_name] = nil
          end
        end
      end
      if init_opts.any?
        fail "unrecognized options: #{init_opts.inspect}"
      end
    end

    def inspect
      "#<#{self.class} #{attributes.map{|k,v| "#{k}: #{v.inspect}"}.join(", ")}>"
    end

    def freeze_attributes
      attributes.values.each(&:freeze)
      attributes.freeze
      self
    end

    class Attribute
      attr_reader :name, :types, :coercer

      def initialize(name, types, coercer)
        @name = name
        @types = types
        @coercer = coercer
      end

      def inspect
        type_str = types.length > 1 ? types.join("|") : types[0]
        "#{name}: #{type_str}"
      end
    end
  end
end
