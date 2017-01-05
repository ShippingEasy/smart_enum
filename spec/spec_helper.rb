$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

RSpec.configure do |config|
  config.disable_monkey_patching!
end

require 'smart_enum'
