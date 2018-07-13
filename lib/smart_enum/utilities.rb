# frozen_string_literal: true

class SmartEnum
  module Utilities
    def self.symbolize_hash_keys(original_hash)
      return original_hash if original_hash.each_key.all?{|key| Symbol === key }
      symbolized_hash = {}
      original_hash.each_key do |key|
        symbolized_hash[key.to_sym] = original_hash[key]
      end
      symbolized_hash
    end

    def self.foreign_key(string)
      singularize(string) + "_id"
    end

    def self.singularize(string)
      string.to_s.chomp("s")
    end
  end
end
