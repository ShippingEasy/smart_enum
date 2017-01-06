require "smart_enum/version"
require "smart_enum/active_record_interop"
require "smart_enum/associations"
require "smart_enum/attributes"
require "smart_enum/monetize_interop"
require "smart_enum/querying"
require "smart_enum/registration"

require "active_support/all" # TODO: only require parts we need
require "active_record" # Temporary: should become opt-in

# A class used to build in-memory graphs of "lookup" objects that are
# long-lived and can associate among themselves or ActiveRecord instances.
#
# Example:
#
#   class Foo < SmartEnum
#     attribute :id, Integer
#     has_many :accounts, :class_name => "Customer"
#   end
#
#   class Bar < SmartEnum
#     attribute :foo_id, Integer
#     belongs_to :foo
#   end
#
#   Foo.register_values([{id: 1},{id: 2}])
#   Bar.register_values([{id:9, foo_id: 1},{id: 10, foo_id: 2}])
#   Bar.find(1)
#   # ActiveRecord::RecordNotFound: Couldn't find Bar with 'id'=1
#   bar = Bar.find(9)
#   # => #<Bar:0x007fcb6440a1f0 @attributes={:foo_id=>1, :id=>9}>
#   bar.foo
#   # => #<Foo:0x007fcb643633c8 @attributes={:id=>1}>
#   bar.foo.accounts
#   #  Customer Load (1.3ms)  SELECT "customers".* FROM "customers" WHERE "customers"."foo_id" = 1
#   # => [#<Customer id: 13, foo_id: 1>, ...]
#
class SmartEnum
  include ActiveModel::Serialization
  include SmartEnum::Attributes

  def self.enum_values
    @enum_values ||= {}
  end

  def self.enum_locked?
    @enum_locked
  end

  extend Registration
  extend Associations
  extend Querying
  include ActiveRecordInterop
  extend MonetizeInterop
end
