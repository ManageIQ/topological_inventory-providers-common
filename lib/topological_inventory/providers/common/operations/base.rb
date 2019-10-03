require "topological_inventory/providers/common/logging"
require "topological_inventory-api-client"
require "topological_inventory/providers/common/operations/topology_api_client"

module TopologicalInventory
  module Providers
    module Common
      module Operations
        class Base
          include Logging
          include TopologyApiClient

          attr_accessor :params, :identity

          def initialize(params = {}, identity = nil)
            @params   = params
            @identity = identity
          end

          def endpoint_client(_source_id, _task_id, _identity)
            raise NotImplementedError, "#{__method__} must be implemented in a subclass as kind of TopologicalInventory::Providers::Common::EndpointClient class"
          end
        end
      end
    end
  end
end