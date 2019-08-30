module TopologicalInventory
  module Providers
    module Common
      class Collector
        class InventoryCollectionWrapper < TopologicalInventoryIngressApiClient::InventoryCollection
          def initialize(name:)
            super(:name => name, :data => [])
          end

          def build(properties)
            obj = get_model.new(properties)
            data << obj
            obj
          end

          protected

          def get_model
            "TopologicalInventoryIngressApiClient::#{name.to_s.classify}".constantize
          end
        end
      end
    end
  end
end
