if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

require "bundler/setup"
require "topological_inventory/providers/common"
require "webmock/rspec"

Dir["./spec/support/**/*.rb"].each {|f| require f}

spec_path = File.dirname(__FILE__)
Dir[File.join(spec_path, "support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
