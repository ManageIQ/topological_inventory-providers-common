require "topological_inventory/providers/common/sources_api_client"

module TopologicalInventory
  module Providers
    module Common
      module Mixins
        module SourcesApi
          AUTH_NOT_NECESSARY = "n/a".freeze

          def sources_api
            @sources_api ||= TopologicalInventory::Providers::Common::SourcesApiClient.new(identity)
          end

          def endpoint
            @endpoint ||= sources_api.fetch_default_endpoint(source_id)
          rescue => e
            metrics&.record_error(:sources_api)
            logger.error_ext(operation, "Failed to fetch Endpoint for Source #{source_id}: #{e.message}")
            nil
          end

          def authentication
            @authentication ||= if endpoint.receptor_node.present?
                                  AUTH_NOT_NECESSARY
                                else
                                  sources_api.fetch_authentication(source_id, endpoint)
                                end
          rescue => e
            metrics&.record_error(:sources_api)
            logger.error_ext(operation, "Failed to fetch Authentication for Source #{source_id}: #{e.message}")
            nil
          end

          def application
            @application ||= sources_api.fetch_application(source_id)
          rescue => e
            metrics&.record_error(:sources_api)
            logger.error_ext(operation, "Failed to fetch Application for Source #{source_id}: #{e.message}")
            nil
          end

          def on_premise?
            @on_premise ||= endpoint&.receptor_node.to_s.strip.present?
          end

          def verify_ssl_mode
            endpoint&.verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
          end

          def full_hostname(endpoint)
            if on_premise?
              "receptor://#{endpoint.receptor_node}"
            else
              endpoint.host.tap { |host| host << ":#{endpoint.port}" if endpoint.port }
            end
          end
        end
      end
    end
  end
end
