# frozen_string_literal: true

require 'yaml'
# Methods for registering values from YAML files
class SmartEnum
  module YamlStore
    def register_values_from_file!
      unless SmartEnum::YamlStore.data_root
        raise "Must set SmartEnum::YamlStore.data_root before using `register_values_from_file!`"
      end
      unless self.name
        raise "Cannot infer data file for anonymous class"
      end

      filename = "#{self.name.tableize}.yml"
      file_path = File.join(SmartEnum::YamlStore.data_root, filename)
      values = YAML.load_file(file_path)
      register_values(values, self, detect_sti_types: true)
    end

    def self.data_root
      @data_root
    end

    def self.data_root=(val)
      @data_root = val
    end
  end

  # automatically enable YAML store when this file is loaded
  extend YamlStore
end
