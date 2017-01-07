require 'yaml'
# Methods for registering in-memory values
class SmartEnum
  module Registration
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

    def self.data_root
      @data_root
    end

    def self.data_root=(val)
      @data_root = val
    end
  end
end
