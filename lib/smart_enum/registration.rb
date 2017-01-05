# Methods for registering in-memory values
class SmartEnum
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
end
