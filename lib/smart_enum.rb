require "smart_enum/version"
require "smart_enum/associations"
require "smart_enum/attributes"

require "active_support/all" # TODO: only require parts we need

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

    private def _constantize_cache
      @_constantize_cache ||= {}
    end

    private def _descends_from_cache
      @_descends_from_cache ||= {}
    end
  end

  extend Associations

  def self.lock_enum!
    return if @enum_locked
    @enum_locked = true
    @_constantize_cache = nil
    @_descends_from_cache = nil

    _enum_storage.freeze
    self.descendants.each do |klass|
      klass.lock_enum!
    end
  end

  def self.register_values(values, enum_type=self, detect_sti_types: false)
    values.each do |raw_attrs|
      register_value(enum_type: enum_type, detect_sti_types: detect_sti_types, **raw_attrs.symbolize_keys)
    end
    lock_enum!
  end

  # TODO: allow a SmartEnum to define its own type discriminator attr?
  DEFAULT_TYPE_ATTR_STR = "type".freeze
  DEFAULT_TYPE_ATTR_SYM = :type

  def self.register_value(enum_type: self, detect_sti_types: false, **attrs)
    fail EnumLocked.new(enum_type) if enum_locked?
    type_attr_val = attrs[DEFAULT_TYPE_ATTR_STR] || attrs[DEFAULT_TYPE_ATTR_SYM]
    klass = if type_attr_val && detect_sti_types
              _constantize_cache[type_attr_val] ||= type_attr_val.constantize
            else
              enum_type
            end
    unless (_descends_from_cache[klass] ||= (klass <= self))
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

  class EnumLocked < StandardError
    def initialize(klass)
      super("#{klass} has been locked and can not be written to")
    end
  end
end
