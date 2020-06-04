source "https://rubygems.org"

plugin 'bundler-inject', '~> 1.1'
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

# Specify your gem's dependencies in topological_inventory-providers-common.gemspec
gemspec

group :development, :test do
  gem 'rake', '>= 12.3.3'
  gem 'pry-byebug'
end
