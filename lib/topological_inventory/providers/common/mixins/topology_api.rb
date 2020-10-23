require "topological_inventory/providers/common/topology_api_client"

module TopologicalInventory
  module Providers
    module Common
      module Mixins
        module TopologyApi
          # @identity attr_reader is expected
          def topology_api
            @topology_api ||= TopologicalInventory::Providers::Common::TopologyApiClient.new(identity)
          end

          def update_task(task_id, source_id: nil, state:, status:, target_type: nil, target_source_ref: nil, context: nil)
            topology_api.update_task(task_id,
                                     :source_id         => source_id,
                                     :state             => state,
                                     :status            => status,
                                     :target_type       => target_type,
                                     :target_source_ref => target_source_ref,
                                     :context           => context)
          end
        end
      end
    end
  end
end
