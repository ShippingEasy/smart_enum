require 'bigdecimal'
require "active_record"

# Methods to make SmartEnum models work in contexts like views where rails
# expects ActiveRecord instances.
class SmartEnum
  module ActiveRecordCompatibility
    def self.included(base)
      base.include(ActiveModel::Serialization)
      base.extend(ActiveModel::Naming)
      base.extend(ClassMethods)
      base.extend(QueryMethods)
    end

    module ClassMethods
      ID = "id".freeze
      def primary_key
        ID
      end

      def reset_column_information
        # no-op for legacy migration compatability
      end

      # Used in AR polymorphic associations.  Returns the base of this class' SmartEnum STI tree.
      def base_class
        unless self < ::SmartEnum
          raise ActiveRecordError, "#{name} doesn't belong in a hierarchy descending from SmartEnum"
        end

        if superclass == ::SmartEnum
          self
        else
          superclass.base_class
        end
      end
    end

    def to_key
      [id]
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

    # Simulate ActiveRecord Query API
    module QueryMethods
      def where(uncast_attrs)
        attrs = cast_query_attrs(uncast_attrs)
        all.select do |instance|
          instance.attributes.slice(*attrs.keys) == attrs
        end.tap(&:freeze)
      end

      def find(id, raise_on_missing: true)
        self[cast_primary_key(id)].tap do |result|
          if !result && raise_on_missing
            fail ActiveRecord::RecordNotFound.new("Couldn't find #{self} with 'id'=#{id}")
          end
        end
      end

      def find_by(uncast_attrs)
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
        values
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
  end

  # automatically enable when this file is loaded
  include ActiveRecordCompatibility
end
