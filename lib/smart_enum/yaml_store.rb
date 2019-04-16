# frozen_string_literal: true

require 'yaml'
# Methods for registering values from YAML files
class SmartEnum
  module YamlStore
    # Loads values from a YAML file or files
    #
    # Looks for a file or directory named after the enum type in the data root.
    # If a directory is found, values from all of the YAML files in that directory
    # are loaded.
    # Otherwise, values are loaded from the file named after the enum.
    def register_values_from_file!
      unless SmartEnum::YamlStore.data_root
        raise "Must set SmartEnum::YamlStore.data_root before using `register_values_from_file!`"
      end
      unless self.name
        raise "Cannot infer data file for anonymous class"
      end

      basename = SmartEnum::Utilities.tableize(self.name)
      dirname = File.join(SmartEnum::YamlStore.data_root, basename)
      inferred_file = File.join(SmartEnum::YamlStore.data_root, "#{basename}.yml")
      files = if Dir.exists?(dirname)
                if File.exists?(inferred_file)
                  raise AmbiguousSource, "#{self} values should be defined in inferred file or directory, not both"
                end
                Dir[File.join(dirname, "*.yml")]
              else
                [inferred_file]
              end
      files.each do |file_path|
        values = YAML.load_file(file_path)
        register_values(values, self, detect_sti_types: true)
      end
    end

    def self.data_root
      @data_root
    end

    def self.data_root=(val)
      @data_root = val
    end

    class AmbiguousSource < RuntimeError; end
  end

  # automatically enable YAML store when this file is loaded
  extend YamlStore
end
