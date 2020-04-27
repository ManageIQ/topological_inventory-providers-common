source "https://rubygems.org"

plugin 'bundler-inject', '~> 1.1'
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

# Specify your gem's dependencies in topological_inventory-providers-common.gemspec
gemspec

gem "sources-api-client", "~> 1.0"
gem "topological_inventory-ingress_api-client", "~> 1.0"

group :development, :test do
  gem 'rake', '~> 12.0.0'
  gem 'pry-byebug'
  gem 'timecop'
end
