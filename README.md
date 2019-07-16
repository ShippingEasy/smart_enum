# SmartEnum

SmartEnum provides a way to manage, relate and query a certain kind of "lookup"
data that many applications need.  It is most useful when the data looks
relatively relational and wants to associate with other lookup data or with
persisted data.

## Rationale

Consider a multitenant SAAS rails application that needs to model its list of
subscription plans.  Customer accounts are associated with a given plan and
many parts of the application's behavior change based on the plan of the
customer currently being handled.  The path of least resistance is to treat
`Plan` as a persisted relational model: make a `plans` table, add
`Customer.belongs_to :plan`, and create a migration to create the table and
populate the list of plans you want to make available.  But this strategy
becomes problematic once an application grows beyond a single database.
Changes to the list of plans or the `Plan` model often require a database
migration that must be carefully synchronized across multiple shards.  You also
risk identifiers going out of sync: there are a number of ways that you can end
up in a situation where shards A and B do not agree on what `plan_id=3` refers
to.   All of this can be mitigated, but it points to the fact that this type of
information is *part of your codebase*, and it should be stored alongside the
code.  SmartEnum provides a scheme to do this while preserving some of the
conveniences of using persisted data, like model associations and a query DSL.

## Installation

SmartEnum requires ruby 2.4.0 or above.  It integrates with rails but does not require it to function.

Add this line to your application's Gemfile:

```ruby
gem 'smart_enum'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install smart_enum

## Usage

### Simple example (without rails or yaml files)

```ruby

class Plan < SmartEnum
  attribute :id, Integer
  attribute :name, String
  attribute :user_limit, Integer
  attribute :monthly_cost_cents, Integer
end

Plan.register_values([
  {id: 1, name: 'Basic', user_limit: 1},
  {id: 2, name: 'Premium', user_limit: 5}
])

Plan.find(1).name
# => "Basic"
Plan.find_by(name: 'Premium').id
# => 2
```

### Associating with other SmartEnum models and Rails models

The folowing
[macros](https://github.com/ShippingEasy/smart_enum/blob/master/lib/smart_enum/associations.rb)
are provided:

 - `has_many_enums`
 - `has_one_enum`
 - `has_one_enum_through`
 - `has_many_enums_through`
 - `belongs_to_enum`

The target of these macros must be a SmartEnum class, but any class can be the
source.

```ruby

class UserLimitPolicy < SmartEnum
  attribute :id, String
  attribute :max_count, Integer

  def unlimited?
    max_count == nil
  end
end

class Plan < SmartEnum
  attribute :id, String
  attribute :name, String
  attribute :user_limit_policy_id, String
  belongs_to_enum :user_limit_policy
end

class Customer < ApplicationRecord
  extend SmartEnum::Associations
  belongs_to_enum :plan
end


UserLimitPolicy.register_values([
  {id: 'five_users', max_count: 5},
  {id: 'unlimited'}
])

Plan.register_values([
  {id: 'basic', name: 'Basic',   user_limit_policy_id: 'five_users'},
  {id: 'prem',  name: 'Premium', user_limit_policy_id: 'unlimited'}
])

# Associate among SmartEnum classes
Plan.find(2).user_limit_policy.unlimited?
# => true
Plan.find(1).user_limit_policy.unlimited?
# => false

# Associate with persisted models
Customer.new(plan_id: 'premium').plan.user_limit_policy.unlimited?
# => true

Plan.find(1).name
# => "Basic"
Plan.find_by(name: 'Premium').id
# => 2
```

### Store data in YAML files

This is the recommended way to manage data for convenience and compatibility
with rails autoloading.

```ruby
# config/initializers/000_smart_enum.rb
SmartEnum::YamlStore.data_root = Rails.root.join("data/lookups")
```

```yaml
# data/lookups/plans.yml
---
- id: 1
  name: Basic
- id: 2
  name: Premium
```

```ruby
# app/models/plan.rb
class Plan < SmartEnum
  attribute :id, String
  attribute :name, String

  # infers yaml location by name and loads all data
  register_values_from_file!
end
```

### Custom type coercion

SmartEnum attributes are typechecked on initialization, so the following will fail:
```ruby
class Package < SmartEnum
  attribute :id, Integer
  attribute :length, BigDecimal
  attribute :width, BigDecimal
  attribute :height, BigDecimal
end

Package.register_values([{id: 1, length: 1, width: 2, height: 3}])
# RuntimeError (Attribute :length passed 1:Integer in initializer, but needs [BigDecimal] and has no coercer)
```

One option here is to use attribute coercers:

```ruby
class Package < SmartEnum
  attribute :id, Integer
  attribute :length, BigDecimal, coercer: -> arg { BigDecimal(arg) }
  attribute :width, BigDecimal, coercer: -> arg { BigDecimal(arg) }
  attribute :height, BigDecimal, coercer: -> arg { BigDecimal(arg) }
end

Package.register_values([{id: 1, length: 1, width: 2, height: 3}])
Package.find(1).length.class
# => BigDecimal
```

### Single Table Inheritence

SmartEnum supports a mechanism that works like single table inheritence in
rails: a collection of registered records can have different classes depending
on the content of each record's `type` column:

```ruby
class Vehicle < SmartEnum
  attribute :id, Integer
  attribute :type, String
  attribute :make, String
  attribute :model, String

  def display_name
    "#{make} #{model}"
  end
end

class Car < Vehicle
  def requires_commercial_license?
    false
  end
end

class SemiTruck < Vehicle
  def requires_commercial_license?
    true
  end
end

data = [
  {id: 1, type: 'Car', make: 'Toyota', model: 'Camry'},
  {id: 2, type: 'SemiTruck', make: 'Freightliner', model: 'Cascadia'}
]
Vehicle.register_values(data, detect_sti_types: true)
Vehicle.all.map {|v| [v.display_name, v.requires_commercial_license?]}
# => [["Toyota Camry", false], ["Freightliner Cascadia", true]]
```

### Validating data in SmartEnum

Currently there is no built in way to validate the data in SmartEnum.
The pattern that we suggest is to add an automated test to
validate that the data in SmartEnum models matches what the business logic
requires.


## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ShippingEasy/smart_enum.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
