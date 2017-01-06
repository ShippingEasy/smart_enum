# Macros for registring associations with other SmartEnum models
class SmartEnum
  module Associations
    def has_many_enums(association_name, class_name: nil, as: nil, foreign_key: nil, through: nil, source: nil, **opts)
      if opts.any?
        fail "unsupported options: #{opts.keys.join(',')}"
      end
      association_name = association_name.to_sym
      if through
        return has_many_enums_through(association_name, through, source: source)
      end
      define_method(as || association_name) do
        foreign_key ||= self.class.name.foreign_key
        foreign_key = foreign_key.to_sym
        class_name ||= association_name.to_s.classify
        association_class = class_name.constantize
        ::SmartEnum::Associations.__assert_enum(association_class, :has_many_enums)
        association_class.where({foreign_key => self.id})
      end
    end

    def has_one_enum(association_name, class_name: nil, foreign_key: nil, through: nil, source: nil, **opts)
      if opts.any?
        fail "unsupported options: #{opts.keys.join(',')}"
      end
      if through
        return has_one_enum_through(association_name, through, source: source)
      end
      define_method(association_name) do
        foreign_key ||= self.class.name.foreign_key
        foreign_key = foreign_key.to_sym
        class_name ||= association_name.to_s.classify
        association_class = class_name.constantize
        ::SmartEnum::Associations.__assert_enum(association_class, :has_one_enum)
        association_class.find_by({foreign_key => self.id})
      end
    end

    def has_one_enum_through(association_name, through_association, source: nil)
      define_method(association_name) do
        association_method = source || association_name
        send(through_association).try(association_method)
      end
    end

    def has_many_enums_through(association_name, through_association, source: nil)
      define_method(association_name) do
        association_method = source || association_name
        send(through_association).compact.flat_map(&association_method).compact.tap(&:freeze)
      end
    end

    def belongs_to_enum(association_name, class_name: nil, foreign_key: nil, read_only: true, **opts)
      if opts.any?
        fail "unsupported options: #{opts.keys.join(',')}"
      end
      foreign_key ||= association_name.to_s.foreign_key
      class_name ||= association_name.to_s.classify
      association_class = class_name.constantize
      ::SmartEnum::Associations.__assert_enum(association_class, :belongs_to_enum)
      self.enum_associations[association_name.to_sym] =
        BelongsToAssociation.new(association_name, foreign_key, association_class)

      define_method(association_name) do
        association_class.find_by(id: self.public_send(foreign_key))
      end

      unless read_only
        define_method("#{association_name}=") do |value|
          self.public_send("#{foreign_key}=", value.try(:id))
        end
      end
    end

    def self.__assert_enum(klass, macro_name)
      unless klass <= SmartEnum
        fail "#{macro_name} should only be used to associate against SmartEnum descendants, #{klass} isn't one"
      end
    end

    def enum_associations
      @enum_associations ||= {}
    end

    class BelongsToAssociation
      attr_accessor :association_name, :foreign_key, :association_class

      def initialize(association_name, foreign_key, association_class)
        @association_name = association_name.to_sym
        @foreign_key = foreign_key.to_sym
        @association_class = association_class
      end
    end
  end
end
