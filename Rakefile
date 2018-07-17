# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec_noar) { |t| t.exclude_pattern = "spec/active_record_compatibility_spec.rb" }
RSpec::Core::RakeTask.new(:spec_ar) { |t| t.pattern = "spec/active_record_compatibility_spec.rb" }

task spec: [:spec_noar, :spec_ar]

task :default => :spec
