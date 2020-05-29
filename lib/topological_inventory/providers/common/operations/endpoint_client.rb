require "topological_inventory/providers/common/operations/topology_api_client"
require "topological_inventory/providers/common/operations/sources_api_client"

module TopologicalInventory
  module Providers
    module Common
      module Operations
        class EndpointClient
          include TopologyApiClient

          def initialize(source_id, task_id, identity = nil)
            self.identity   = identity
            self.source_id  = source_id
            self.task_id    = task_id
          end

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

          private

          attr_accessor :identity, :task_id, :source_id

          def sources_api
            @sources_api ||= SourcesApiClient.new(identity)
          end

          def default_endpoint
            @default_endpoint ||= sources_api.fetch_default_endpoint(source_id)
            raise "Sources API: Endpoint not found! (source id: #{source_id})" if @default_endpoint.nil?

            @default_endpoint
          end

          def authentication
            @authentication ||= sources_api.fetch_authentication(source_id, default_endpoint)
          end

          def verify_ssl_mode
            default_endpoint.verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
          end
        end
      end
    end
  end
end
