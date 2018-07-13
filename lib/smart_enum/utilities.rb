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
      singularize(tableize(string)) + "_id"
    end

    def self.singularize(string)
      string.to_s.chomp("s")
    end

    def self.tableize(string)
      underscore(string) + "s"
    end

    def self.classify(string)
      singularize(camelize(string))
    end

    # Convert snake case string to camelcase string.
    # Adapted from https://github.com/jeremyevans/sequel/blob/5.10.0/lib/sequel/model/inflections.rb#L103
    def self.camelize(string)
      string.to_s
        .gsub(/\/(.?)/){|x| "::#{x[-1..-1].upcase unless x == '/'}"}
        .gsub(/(^|_)(.)/){|x| x[-1..-1].upcase}
    end

    # Adapted from
    # https://github.com/jeremyevans/sequel/blob/5.10.0/lib/sequel/model/inflections.rb#L147-L148
    def self.underscore(string)
      string
        .to_s
        .gsub(/::/, '/')
        .gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
        .gsub(/([a-z\d])([A-Z])/,'\1_\2')
        .tr("-", "_")
        .downcase
    end
  end
end
