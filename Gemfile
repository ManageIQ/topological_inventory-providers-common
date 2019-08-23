source "https://rubygems.org"

plugin 'bundler-inject', '~> 1.1'
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

# Specify your gem's dependencies in topological_inventory-providers-common.gemspec
gemspec

gem "sources-api-client",                       :git => "https://github.com/ManageIQ/sources-api-client-ruby", :branch => "master"
gem 'topological_inventory-api-client',         :git => "https://github.com/ManageIQ/topological_inventory-api-client-ruby", :branch => "master"
gem "topological_inventory-ingress_api-client", :git => "https://github.com/ManageIQ/topological_inventory-ingress_api-client-ruby", :branch => "master"
