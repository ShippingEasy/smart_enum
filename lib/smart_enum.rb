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
  include SeAttributes

  def self.enum_values
    @enum_values ||= {}
  end

  def self.enum_locked?
    @enum_locked
  end

  # Methods for registering in-memory values
  module Registration
    class EnumLocked < StandardError
      def initialize(klass)
        super("#{klass} has been locked and can not be written to")
      end
    end

    def lock_enum!
      @enum_locked = true
      enum_values.freeze
      self.descendants.each do |klass|
        klass.instance_variable_set(:@enum_locked, true)
        klass.enum_values.freeze
      end
    end

    def register_values_from_file!
      values = YAML.load_file(Rails.root.join("data/lookups/#{self.name.tableize}.yml"))
      register_values(values, self, detect_sti_types: true)
    end

    def register_values(values, enum_type=self, detect_sti_types: false)
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
        raise "Already registered id #{id}!" if enum_values.has_key?(id)
        enum_values[id] = instance
        if klass != self
          klass.enum_values[id] = instance
        end
      end
      lock_enum!
    end

    def register_value(enum_type: self, **attrs)
      fail EnumLocked.new(enum_type) if enum_locked?
      unless enum_type <= self
        raise "Specified class #{enum_type} must derive from #{self}"
      end
      instance = enum_type.new(attrs)
      id = instance.id
      raise "Must provide id" unless id
      raise "Already registered id #{id}!" if enum_values.has_key?(id)
      enum_values[id] = instance
    end

    # in config/initializer/smart_enum.rb:
    # SmartEnum.lock_all!
    def lock_all!
      # FIXME: This wont work, because lazy loaded classes aren't loaded yet
      subclasses.each do |subclass|
        subclass.lock_enum!
      end
    end
  end

  # Macros for registring associations with other SmartEnum models
  module Association
    BelongsToReflection = Struct.new(:association_name, :foreign_key, :association_class)

    def has_many(association_name, class_name: nil, as: nil, foreign_key: nil, through: nil, source: nil, **opts)
      if opts.any?
        fail "unsupported options: #{opts.keys.join(',')}"
      end
      association_name = association_name.to_sym
      if through
        return has_many_through(association_name, through, source: source)
      end
      define_method(as || association_name) do
        foreign_key ||= self.class.name.foreign_key
        foreign_key = foreign_key.to_sym
        class_name ||= association_name.to_s.classify
        association_class = class_name.constantize
        association_class.where({foreign_key => self.id})
      end
    end

    def has_one(association_name, class_name: nil, foreign_key: nil, **opts)
      if opts.any?
        fail "unsupported options: #{opts.keys.join(',')}"
      end
      association_name = association_name.to_sym
      define_method(association_name) do
        foreign_key ||= self.class.name.foreign_key
        foreign_key = foreign_key.to_sym
        class_name ||= association_name.to_s.classify
        association_class = class_name.constantize
        association_class.find_by({foreign_key => self.id})
      end
    end

    def has_many_through(association_name, through_association, source: nil)
      define_method(association_name) do
        association_method = source || association_name
        send(through_association).flat_map(&association_method).freeze
      end
    end

    def belongs_to(association_name, class_name: nil, foreign_key: nil, **opts)
      if opts.any?
        fail "unsupported options: #{opts.keys.join(',')}"
      end
      association_name = association_name.to_sym
      foreign_key ||= association_name.to_s.foreign_key
      foreign_key = foreign_key.to_sym
      class_name ||= association_name.to_s.classify
      association_class = class_name.constantize
      self.reflections[association_name] =
        BelongsToReflection.new(association_name, foreign_key, association_class)

      define_method(association_name) do
        association_class.find_by(id: self.attributes.fetch(foreign_key))
      end
    end

    def reflections
      @reflections ||= {}
    end
  end

  module Querying
    def where(uncast_attrs)
      raise "Cannot use unlocked enum" unless @enum_locked
      attrs = cast_query_attrs(uncast_attrs)
      all.select do |instance|
        instance.attributes.slice(*attrs.keys) == attrs
      end.tap(&:freeze)
    end

    def find(id, raise_on_missing: true)
      raise "Cannot use unlocked enum" unless @enum_locked
      enum_values[cast_primary_key(id)].tap do |result|
        if !result && raise_on_missing
          fail ActiveRecord::RecordNotFound.new("Couldn't find #{self} with 'id'=#{id}")
        end
      end
    end

    def find_by(uncast_attrs)
      raise "Cannot use unlocked enum" unless @enum_locked
      attrs = cast_query_attrs(uncast_attrs)
      if attrs.size == 1 && attrs.has_key?(:id)
        return find(attrs[:id], raise_on_missing: false)
      end
      all.detect do |instance|
        instance.attributes.slice(*attrs.keys) == attrs
      end
    end

    def find_by!(attrs)
      find_by(attrs).tap do |result|
        if !result
          fail ActiveRecord::RecordNotFound.new("Couldn't find #{self} with #{attrs.inspect}")
        end
      end
    end

    def none
      []
    end

    def all
      enum_values.values
    end

    STRING = [String]
    SYMBOL = [Symbol]
    BOOLEAN = [TrueClass, FalseClass]
    INTEGER = [Integer]
    BIG_DECIMAL = [BigDecimal]
    # Ensure that the attrs we query by are compatible with the internal
    # types, casting where possible.  This allows us to e.g.
    #   find_by(id: '1', key: :blah)
    # even when types differ like we can in ActiveRecord.
    def cast_query_attrs(raw_attrs)
      raw_attrs.symbolize_keys.each_with_object({}) do |(k, v), new_attrs|
        if v.instance_of?(Array)
          fail "SmartEnum can't query with array arguments yet.  Got #{raw_attrs.inspect}"
        end
        if (attr_def = attribute_set[k])
          if attr_def.types.any?{|type| v.instance_of?(type) }
            # No need to cast
            new_attrs[k] = v
          elsif (v.nil? && attr_def.types != BOOLEAN)
            # Querying by nil is a legit case, unless the type is boolean
            new_attrs[k] = v
          elsif attr_def.types == STRING
            new_attrs[k] = String(v)
          elsif attr_def.types == INTEGER
            if v.instance_of?(String) && v.empty? # support querying by (id: '')
              new_attrs[k] = nil
            else
              new_attrs[k] = Integer(v)
            end
          elsif attr_def.types == BOOLEAN
            # TODO should we treat "f", 0, etc as false?
            new_attrs[k] = !!v
          elsif attr_def.types == BIG_DECIMAL
            new_attrs[k] = BigDecimal(v)
          else
            fail "Passed illegal query arguments for #{k}: #{v} is a #{v.class}, need #{attr_def.types} or a cast rule (got #{raw_attrs.inspect})"
          end
        else
          fail "#{k} is not an attribute of #{self}! (got #{raw_attrs.inspect})"
        end
      end
    end

    # Given an "id-like" parameter (usually the first argument to find),
    # cast it to the same type used to index the PK lookup hash.
    def cast_primary_key(id_input)
      return if id_input == nil
      id_attribute = attribute_set[:id]
      fail "no :id attribute defined on #{self}" if !id_attribute
      types = id_attribute.types
      # if the type is already compatible, return it.
      return id_input if types.any? { |t| id_input.instance_of?(t) }
      case types
      when INTEGER then Integer(id_input)
      when STRING  then id_input.to_s
      when SYMBOL  then id_input.to_s.to_sym
      else
        fail "incompatible type: got #{id_input.class}, need #{types.inspect} or something castable to that"
      end
    end
  end

  # Methods to make SmartEnum models work in contexts like views where rails
  # expects ActiveRecord instances.
  module ActiveRecordInterop
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      ID = "id".freeze
      def primary_key
        ID
      end

      def reset_column_information
        # no-op for legacy migration compatability
      end
    end

    def to_key
      [id]
    end

    def model_name
      ActiveModel::Name.new(self)
    end

    def _read_attribute(attribute_name)
      attributes.fetch(attribute_name.to_sym)
    end

    def destroyed?
      false
    end

    def new_record?
      false
    end

    def marked_for_destruction?
      false
    end

    def persisted?
      true
    end
  end


  # Simple emulation of the monetize macro.
  INTEGER = [Integer]
  module MonetizeInterop
    CENTS_SUFFIX = /_cents\z/.freeze
    # Note: this ignores the currency column since we only ever monetize things
    # as USD.  If that changes this should start reading the currency column.
    def monetize(cents_field_name, as: nil, **opts)
      if opts.any?
        fail "unsupported options: #{opts.keys.join(',')}"
      end

      attr_def = attribute_set[cents_field_name.to_sym]
      if !attr_def
        fail "no attribute called #{cents_field_name}, (Do you need to add '_cents'?)"
      end

      if attr_def.types != INTEGER
        fail "attribute #{cents_field_name.inspect} can't monetize, only Integer is allowed"
      end

      money_attribute = as || cents_field_name.to_s.sub(CENTS_SUFFIX, '')

      should_memoize = !Rails.env.test?

      define_method(money_attribute) do
        if should_memoize
          @money_cache ||= {}
          @money_cache[money_attribute] ||= Money.new(public_send(cents_field_name))
        else
          Money.new(public_send(cents_field_name))
        end
      end
    end
  end


  extend Registration
  extend Association
  extend Querying
  include ActiveRecordInterop
  extend MonetizeInterop
end
