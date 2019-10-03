require "topological_inventory/providers/common/operations/base"
require "topological_inventory/providers/common/operations/core/service_order_mixin"

module TopologicalInventory
  module Providers
    module Common
      module Operations
        class ServicePlan < TopologicalInventory::Providers::Common::Operations::Base
          include Core::ServiceOrderMixin
        end
      end
    end
  end
end