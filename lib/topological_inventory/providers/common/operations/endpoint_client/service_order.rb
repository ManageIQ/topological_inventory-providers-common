require "topological_inventory/providers/common/operations/endpoint_client"

module TopologicalInventory
  module Providers
    module Common
      module Operations
        class EndpointClient
          class ServiceOrder < TopologicalInventory::Providers::Common::Operations::EndpointClient
            def order_service(service_offering, service_plan, order_params)
              raise NotImplementedError, "#{__method__} must be implemented in a subclass"
            end

            def source_ref_of(endpoint_svc_instance)
              raise NotImplementedError, "#{__method__} must be implemented in a subclass"
            end

            def wait_for_provision_complete(source_id, endpoint_svc_instance, context = {})
              raise NotImplementedError, "#{__method__} must be implemented in a subclass"
            end

            def provisioned_successfully?(endpoint_svc_instance)
              raise NotImplementedError, "#{__method__} must be implemented in a subclass"
            end

            # Endpoint for conversion of provisioned service's status to
            # TopologicalInventory Task's status
            def task_status_for(endpoint_svc_instance)
              raise NotImplementedError, "#{__method__} must be implemented in a subclass"
            end
          end
        end
      end
    end
  end
end
