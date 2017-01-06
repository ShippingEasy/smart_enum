$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.before(:all) do
    SmartEnum::Registration.data_root = nil
  end
end

require 'smart_enum'
