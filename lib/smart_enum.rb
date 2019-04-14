# frozen_string_literal: true

require "smart_enum/version"
require "smart_enum/associations"
require "smart_enum/attributes"
require "smart_enum/utilities"

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
    ensure_ready_for_reads!
    _enum_storage[id]
  end

  def self.values
    ensure_ready_for_reads!
    _enum_storage.values
  end

  def self.enum_locked?
    @enum_locked
  end

  class << self
    attr_accessor :abstract_class

    protected def _enum_storage
      @_enum_storage ||= {}
    end

    protected def ensure_ready_for_reads!
      return true if enum_locked?
      # This method must be called on a base class if in an STI heirarachy,
      # because that is the only place deferred hashes are stored.
      if superclass != SmartEnum
        return superclass.ensure_ready_for_reads!
      end
      if @_deferred_values_present
        # if we have deferred hashes, instantiate them and lock the enum
        process_deferred_attr_hashes
        lock_enum!
      else
        # No instance registration has been attempted, need to call
        # register_values or register_value and lock_enum! first.
        raise EnumUnlocked, self
      end
    end

    private def _constantize_cache
      @_constantize_cache ||= {}
    end

    private def _descends_from_cache
      @_descends_from_cache ||= {}
    end

    # The descendants of a class.  From activesupport's Class#descendants
    private def class_descendants(klass)
      descendants = []
      ObjectSpace.each_object(klass.singleton_class) do |k|
        next if k.singleton_class?
        descendants.unshift k unless k == self
      end
      descendants
    end

    private def _deferred_attr_hashes
      @_deferred_attr_hashes ||= []
    end

    private def process_deferred_attr_hashes
      _deferred_attr_hashes.each do |args|
        register_value(**args)
      end
    end
  end

  extend Associations

  def self.lock_enum!
    return if @enum_locked
    @enum_locked = true
    @_constantize_cache = nil
    @_descends_from_cache = nil

    _enum_storage.freeze
    class_descendants(self).each do |klass|
      klass.lock_enum!
    end
  end

  def self.register_values(values, enum_type=self, detect_sti_types: false)
    values.each do |raw_attrs|
      _deferred_attr_hashes << SmartEnum::Utilities.symbolize_hash_keys(raw_attrs).merge(enum_type: enum_type, detect_sti_types: detect_sti_types)
    end
    @_deferred_values_present = true
  end

  # TODO: allow a SmartEnum to define its own type discriminator attr?
  DEFAULT_TYPE_ATTR_STR = "type"
  DEFAULT_TYPE_ATTR_SYM = :type

  def self.register_value(enum_type: self, detect_sti_types: false, **attrs)
    fail EnumLocked.new(enum_type) if enum_locked?
    type_attr_val = attrs[DEFAULT_TYPE_ATTR_STR] || attrs[DEFAULT_TYPE_ATTR_SYM]
    klass = if type_attr_val && detect_sti_types
              _constantize_cache[type_attr_val] ||= SmartEnum::Utilities.constantize(type_attr_val)
            else
              enum_type
            end
    unless (_descends_from_cache[klass] ||= (klass <= self))
      raise RegistrationError.new("Specified class must derive from #{self}", type: klass, attributes: attrs)
    end
    if klass.abstract_class
      raise RegistrationError, "#{klass} is marked as abstract and may not be registered"
    end

    instance = klass.new(attrs)
    id = instance.id
    unless id
      raise MissingIDError.new(type: klass, attributes: attrs)
    end
    if _enum_storage.has_key?(id)
      raise DuplicateIDError.new(type: klass, attributes: attrs, id: id, existing: _enum_storage[id])
    end
    instance.freeze_attributes
    _enum_storage[id] = instance
    if klass != self
      klass._enum_storage[id] = instance
    end
  end

  class EnumLocked < StandardError
    attr_reader :type

    def initialize(klass)
      @type = klass
      super("#{klass} has been locked and can not be written to")
    end
  end

  class EnumUnlocked < StandardError
    attr_reader :type

    def initialize(klass)
      @type = klass
      super("Cannot use unlocked enum #{klass}.")
    end
  end

  class RegistrationError < StandardError
    attr_reader :type, :attributes

    def initialize(info=nil, type: nil, attributes:{})
      @info = info
      @type = type
      @attributes = attributes
      super("Failed to register enum #{@type} with attributes: #{@attributes}. #{@info}")
    end
  end

  class MissingIDError < RegistrationError
  end

  class DuplicateIDError < RegistrationError
    attr_reader :id, :existing

    def initialize(type:,id:,attributes:,existing:)
      @id = id
      @existing = existing
      super("The ID #{@id} has already been registered with #{existing}", type: type, attributes: attributes)
    end
  end
end
