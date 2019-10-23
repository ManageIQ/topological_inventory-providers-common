require "active_support/inflector"

module TopologicalInventory
  module Providers
    module Common
      class Collector
        class Parser
          attr_accessor :collections, :resource_timestamp

          delegate :add_collection, :to => :collections

          def initialize
            @collections = InventoryCollectionStorage.new

            self.resource_timestamp = Time.now.utc
          end

          def lazy_find(collection, reference, ref: :manager_ref)
            return if reference.kind_of?(String) && reference.blank?

            # Don't make lazy link if all reference values are blank
            return if reference.kind_of?(Hash) && reference.values.select { |val| val.to_s.present? }.blank?

            TopologicalInventoryIngressApiClient::InventoryObjectLazy.new(
              :inventory_collection_name => collection,
              :reference                 => reference,
              :ref                       => ref,
            )
          end
        end
      end
    end
  end
end
