require "topological_inventory-api-client"

module TopologicalInventory
  module Providers
    module Common
      class TopologyApiClient < ::TopologicalInventoryApiClient::ApiClient
        attr_accessor :api

        def initialize(identity = nil)
          super(::TopologicalInventoryApiClient::Configuration.default)

          self.identity = identity
          self.api      = init_default_api
        end

        def init_default_api
          default_headers.merge!(identity) if identity.present?
          ::TopologicalInventoryApiClient::DefaultApi.new(self)
        end

        def update_task(task_id, source_id: nil, state:, status:, target_type: nil, target_source_ref: nil, context: nil)
          params                      = {'state'  => state,
                                         'status' => status}
          params['context']           = context if context
          params['source_id']         = source_id if source_id
          params['target_type']       = target_type if target_type
          params['target_source_ref'] = target_source_ref if target_source_ref
          task                        = TopologicalInventoryApiClient::Task.new(params)
          api.update_task(task_id, task)
        end

        def svc_instance_url(service_instance)
          rest_api_path = '/service_instances/{id}'.sub('{' + 'id' + '}', service_instance&.id.to_s)
          build_request(:GET, rest_api_path).url
        end

        private

        attr_accessor :identity
      end
    end
  end
end
