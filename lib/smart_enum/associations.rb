# Macros for registring associations with other SmartEnum models
class SmartEnum
  module Associations
    def has_many_enums(association_name, class_name: nil, as: nil, foreign_key: nil, through: nil, source: nil)
      association_name = association_name.to_sym
      if through
        return has_many_enums_through(association_name, through, source: source)
      end

      association = enum_associations[association_name] =
        HasMany.new(self, association_name, class_name, as, foreign_key)

      define_method(association.generated_method_name) do
        association.association_class.where(association.foreign_key => self.id)
      end
    end

    def has_one_enum(association_name, class_name: nil, foreign_key: nil, through: nil, source: nil)
      if through
        return has_one_enum_through(association_name, through, source: source)
      end

      association_name = association_name.to_sym
      association = enum_associations[association_name] =
        HasOne.new(self, association_name, class_name, foreign_key)

      define_method(association_name) do
        association.association_class.find_by(association.foreign_key => self.id)
      end
    end

    def has_one_enum_through(association_name, through_association, source: nil)
      association = enum_associations[association_name] =
        HasOneThrough.new(association_name, through_association, source)
      define_method(association_name) do
        public_send(association.through_association).try(association.association_method)
      end
    end

    def has_many_enums_through(association_name, through_association, source: nil)
      association = enum_associations[association_name] =
        HasManyThrough.new(association_name, through_association, source)
      define_method(association_name) do
        public_send(association.through_association).compact.
          flat_map(&association.association_method).compact.tap(&:freeze)
      end
    end

    def belongs_to_enum(association_name, class_name: nil, foreign_key: nil)
      association_name = association_name.to_sym
      association = enum_associations[association_name] =
        BelongsTo.new(association_name, class_name, foreign_key)

      define_method(association_name) do
        id_to_find = self.public_send(association.foreign_key)
        association.association_class.find_by(id: id_to_find)
      end

      fk_writer_name = "#{association.foreign_key}=".to_sym

      generate_writer = instance_methods.include?(fk_writer_name) || (
        # ActiveRecord may not have generated the FK writer method yet.
        # We'll assume that it will get a writer if it has a column with the same name.
        defined?(ActiveRecord::Base) &&
        self <= ActiveRecord::Base &&
        self.respond_to?(:column_names) &&
        self.column_names.include?(association.foreign_key.to_s)
      )

      if generate_writer
        define_method("#{association_name}=") do |value|
          self.public_send(fk_writer_name, value.try(:id))
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

    class BelongsTo
      attr_reader :association_name, :class_name_option, :foreign_key_option

      def initialize(association_name, class_name_option, foreign_key_option)
        @association_name = association_name.to_sym
        @class_name_option = class_name_option
        @foreign_key_option = foreign_key_option
      end

      def class_name
        @class_name ||= (class_name_option || association_name.to_s.classify).to_s
      end

      def foreign_key
        @foreign_key ||= (foreign_key_option || association_name.to_s.foreign_key).to_sym
      end

      def association_class
        @association_class ||= class_name.constantize.tap{|klass|
          ::SmartEnum::Associations.__assert_enum(klass, :belongs_to_enum)
        }
      end
    end

    class HasMany
      attr_reader :owner_class, :association_name, :class_name_option, :as_option, :foreign_key_option

      def initialize(owner_class, association_name, class_name_option, as_option, foreign_key_option)
        @owner_class = owner_class
        @association_name = association_name.to_sym
        @class_name_option = class_name_option
        @as_option = as_option
        @foreign_key_option = foreign_key_option
      end

      def class_name
        @class_name ||= (class_name_option || association_name.to_s.classify).to_s
      end

      def foreign_key
        @foreign_key ||= (foreign_key_option || owner_class.name.foreign_key).to_sym
      end

      def generated_method_name
        @generated_method_name ||= (as_option || association_name).to_sym
      end

      def association_class
        @association_class ||= class_name.constantize.tap{|klass|
             ::SmartEnum::Associations.__assert_enum(klass, :has_many_enums)
           }
      end
    end

    class HasManyThrough
      attr_reader :association_name, :through_association, :source_option

      def initialize(association_name, through_association, source_option)
        @association_name = association_name
        @through_association = through_association.to_sym
        @source_option = source_option
      end

      def association_method
        @association_method ||= (source_option || association_name)
      end
    end

    class HasOne
      attr_reader :owner_class, :association_name, :class_name_option, :foreign_key_option

      def initialize(owner_class, association_name, class_name_option, foreign_key_option)
        @owner_class = owner_class
        @association_name = association_name.to_sym
        @class_name_option = class_name_option
        @foreign_key_option = foreign_key_option
      end

      def foreign_key
        @foreign_key ||= (foreign_key_option || owner_class.name.foreign_key).to_sym
      end

      def class_name
        @class_name ||= (class_name_option || association_name.to_s.classify).to_s
      end

      def association_class
        @association_class ||= class_name.constantize.tap{|klass|
          ::SmartEnum::Associations.__assert_enum(klass, :has_one_enum)
        }
      end
    end

    class HasOneThrough
      attr_reader :association_name, :through_association, :source_option

      def initialize(association_name, through_association, source_option)
        @association_name = association_name
        @through_association = through_association.to_sym
        @source_option = source_option
      end

      def association_method
        @association_method ||= (source_option || association_name)
      end
    end
  end
end
