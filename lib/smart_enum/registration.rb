require 'yaml'
# Methods for registering in-memory values
class SmartEnum
  module Registration
    def lock_enum!
      @enum_locked = true
      enum_values.freeze
      self.descendants.each do |klass|
        klass.instance_variable_set(:@enum_locked, true)
        klass.enum_values.freeze
      end
    end

    def register_values_from_file!
      unless SmartEnum::Registration.data_root
        raise "Must set SmartEnum::Registration.data_root before using `register_values_from_file!`"
      end
      unless self.name
        raise "Cannot infer data file for anonymous class"
      end

      filename = "#{self.name.tableize}.yml"
      file_path = File.join(SmartEnum::Registration.data_root, filename)
      values = YAML.load_file(file_path)
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

    def self.data_root
      @data_root
    end

    def self.data_root=(val)
      @data_root = val
    end
  end

  class EnumLocked < StandardError
    def initialize(klass)
      super("#{klass} has been locked and can not be written to")
    end
  end
end
