require "smart_enum/version"
require "smart_enum/active_record_interop"
require "smart_enum/associations"
require "smart_enum/attributes"
require "smart_enum/querying"

require "active_support/all" # TODO: only require parts we need
require "active_record" # Temporary: should become opt-in

# A class used to build in-memory graphs of "lookup" objects that are
# long-lived and can associate among themselves or ActiveRecord instances.
#
# Example:
#
#   class Foo < SmartEnum
#     attribute :id, Integer
#     has_many :accounts, :class_name => "Customer"
#   end
#
#   class Bar < SmartEnum
#     attribute :foo_id, Integer
#     belongs_to :foo
#   end
#
#   Foo.register_values([{id: 1},{id: 2}])
#   Bar.register_values([{id:9, foo_id: 1},{id: 10, foo_id: 2}])
#   Bar.find(1)
#   # ActiveRecord::RecordNotFound: Couldn't find Bar with 'id'=1
#   bar = Bar.find(9)
#   # => #<Bar:0x007fcb6440a1f0 @attributes={:foo_id=>1, :id=>9}>
#   bar.foo
#   # => #<Foo:0x007fcb643633c8 @attributes={:id=>1}>
#   bar.foo.accounts
#   #  Customer Load (1.3ms)  SELECT "customers".* FROM "customers" WHERE "customers"."foo_id" = 1
#   # => [#<Customer id: 13, foo_id: 1>, ...]
#
class SmartEnum
  include ActiveModel::Serialization
  include SmartEnum::Attributes

  def self.[](id)
    raise "Cannot use unlocked enum" unless @enum_locked
    _enum_storage[id]
  end

  def self.values
    raise "Cannot use unlocked enum" unless @enum_locked
    _enum_storage.values
  end

  def self.enum_locked?
    @enum_locked
  end

  class << self
    protected def _enum_storage
      @_enum_storage ||= {}
    end
  end

  extend Associations
  extend Querying
  include ActiveRecordInterop

  def self.lock_enum!
    @enum_locked = true
    _enum_storage.freeze
    self.descendants.each do |klass|
      klass.instance_variable_set(:@enum_locked, true)
      klass._enum_storage.freeze
    end
  end

  def self.register_values(values, enum_type=self, detect_sti_types: false)
    fail EnumLocked.new(self) if enum_locked?
    constantize_cache = {}
    descends_from_cache = {}
    values.each do |raw_attrs|
      attrs = raw_attrs.symbolize_keys

      klass = if detect_sti_types
                constantize_cache[attrs[:type]] ||= (attrs[:type].try(:constantize) || enum_type)
              else
                enum_type
              end
      unless (descends_from_cache[klass] ||= (klass <= self))
        raise "Specified class #{klass} must derive from #{self}"
      end
      instance = klass.new(attrs)
      id = instance.id
      raise "Must provide id" unless id
      raise "Already registered id #{id}!" if _enum_storage.has_key?(id)
      _enum_storage[id] = instance
      if klass != self
        klass._enum_storage[id] = instance
      end
    end
    lock_enum!
  end

  def self.register_value(enum_type: self, **attrs)
    fail EnumLocked.new(enum_type) if enum_locked?
    unless enum_type <= self
      raise "Specified class #{enum_type} must derive from #{self}"
    end
    instance = enum_type.new(attrs)
    id = instance.id
    raise "Must provide id" unless id
    raise "Already registered id #{id}!" if _enum_storage.has_key?(id)
    _enum_storage[id] = instance
  end

  class EnumLocked < StandardError
    def initialize(klass)
      super("#{klass} has been locked and can not be written to")
    end
  end
end
