# Simple emulation of the monetize macro.
class SmartEnum
  INTEGER = [Integer]
  module MonetizeInterop
    require 'money'

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

      define_method(money_attribute) do
        if MonetizeInterop.memoize_method_value
          @money_cache ||= {}
          @money_cache[money_attribute] ||= Money.new(public_send(cents_field_name))
        else
          Money.new(public_send(cents_field_name))
        end
      end
    end

    @memoize_method_value = true

    def self.memoize_method_value
      @memoize_method_value
    end

    def self.disable_memoization!
      @memoize_method_value = false
    end
  end
end
