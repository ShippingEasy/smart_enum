# Macros for registring associations with other SmartEnum models
class SmartEnum
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
end
