# Methods to make SmartEnum models work in contexts like views where rails
# expects ActiveRecord instances.
class SmartEnum
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
end
