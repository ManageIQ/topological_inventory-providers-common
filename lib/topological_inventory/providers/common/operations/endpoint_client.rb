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

          protected

          attr_accessor :identity, :task_id, :source_id

          def sources_api
            @sources_api ||= SourcesApiClient.new(identity)
          end

          def default_endpoint
            @default_endpoint ||= sources_api.fetch_default_endpoint(source_id)
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
