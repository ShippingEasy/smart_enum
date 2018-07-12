# frozen_string_literal: true

class SmartEnum
  module Utilities
    def self.symbolize_hash_keys(original_hash)
      return original_hash if original_hash.each_key.all?(Symbol)
      symbolized_hash = {}
      original_hash.each_key do |key|
        symbolized_hash[key.to_sym] = original_hash[key]
      end
      symbolized_hash
    end
  end
end
