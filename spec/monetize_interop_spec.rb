require 'spec_helper'
require 'smart_enum/monetize_interop'

RSpec.describe 'monetize' do
  let(:model) {
    Class.new(SmartEnum) do
      extend SmartEnum::MonetizeInterop
      attribute :cost_cents, Integer
      monetize :cost_cents
    end
  }

  it 'supports a limited version of the AR monetize macro' do
    instance = model.new(cost_cents: 1000)
    expect(instance.cost).to eq(Money.new(1000))
  end

  it 'validates that the attribute exists' do
    expect { model.class_eval{ monetize :cost } }.to raise_error(
      "no attribute called cost, (Do you need to add '_cents'?)"
    )
  end

  it 'validates that the attribute is typed correctly' do
    expect {
      model.class_eval {
        attribute :blah_cents, String
        monetize :blah_cents      
      }
    }.to raise_error(
      "attribute :blah_cents can't monetize, only Integer is allowed"
    )
  end
end
