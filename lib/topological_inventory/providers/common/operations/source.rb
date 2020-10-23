require "topological_inventory/providers/common/logging"
require "active_support/core_ext/numeric/time"
require "topological_inventory/providers/common/mixins/sources_api"
require "topological_inventory/providers/common/mixins/x_rh_headers"

module TopologicalInventory
  module Providers
    module Common
      module Operations
        class Source
          include Logging
          include Mixins::SourcesApi
          include Mixins::XRhHeaders

          STATUS_AVAILABLE, STATUS_UNAVAILABLE = %w[available unavailable].freeze

          ERROR_MESSAGES = {
            :authentication_not_found          => "Authentication not found in Sources API",
            :endpoint_or_application_not_found => "Endpoint or Application not found in Sources API",
          }.freeze

          LAST_CHECKED_AT_THRESHOLD = 5.minutes.freeze
          AUTH_NOT_NECESSARY        = "n/a".freeze

          attr_accessor :identity, :operation, :params, :request_context, :source_id, :account_number

          def initialize(params = {}, request_context = nil)
            self.operation       = 'Source'
            self.params          = params
            self.request_context = request_context
            self.source_id       = params['source_id']

            self.account_number  = params['external_tenant']
            self.identity        = identity_by_account_number(account_number)
          end

          def availability_check
            self.operation += '#availability_check'

            return if params_missing?

            return if checked_recently?

            status, error_message = connection_status

            update_source_and_subresources(status, error_message)

            logger.availability_check("Completed: Source #{source_id} is #{status}")
          end

          private

          def required_params
            %w[source_id]
          end

          def params_missing?
            is_missing = false
            required_params.each do |attr|
              if (is_missing = params[attr].blank?)
                logger.availability_check("Missing #{attr} for the availability_check request [Source ID: #{source_id}]", :error)
                break
              end
            end

            is_missing
          end

          def checked_recently?
            checked_recently = if endpoint.present?
                                 endpoint.last_checked_at.present? && endpoint.last_checked_at >= LAST_CHECKED_AT_THRESHOLD.ago
                               elsif application.present?
                                 application.last_checked_at.present? && application.last_checked_at >= LAST_CHECKED_AT_THRESHOLD.ago
                               end

            logger.availability_check("Skipping, last check at #{endpoint.last_checked_at || application.last_checked_at} [Source ID: #{source_id}] ") if checked_recently

            checked_recently
          end

          def connection_status
            # we need either an endpoint or application to check the source.
            return [STATUS_UNAVAILABLE, ERROR_MESSAGES[:endpoint_or_application_not_found]] unless endpoint || application

            check_time
            if endpoint
              endpoint_connection_check
            elsif application
              application_connection_check
            end
          end

          def endpoint_connection_check
            return [STATUS_UNAVAILABLE, ERROR_MESSAGES[:authentication_not_found]] unless authentication

            # call down into the operations pod implementation of `Source#connection_check`
            connection_check
          end

          def application_connection_check
            case application.availability_status
            when "available"
              [STATUS_AVAILABLE, nil]
            when "unavailable"
              [STATUS_UNAVAILABLE, "Application id #{application.id} unavailable"]
            end
          end

          # @return [Array<String, String|nil] - STATUS_[UN]AVAILABLE, error message
          def connection_check
            raise NotImplementedError, "#{__method__} must be implemented in a subclass"
          end

          def update_source_and_subresources(status, error_message = nil)
            logger.availability_check("Updating source [#{source_id}] status [#{status}] message [#{error_message}]")

            update_source(status)

            update_endpoint(status, error_message) if endpoint
            update_application(status) if application
          end

          def update_source(status)
            source                     = ::SourcesApiClient::Source.new
            source.availability_status = status
            source.last_checked_at     = check_time
            source.last_available_at   = check_time if status == STATUS_AVAILABLE

            sources_api.update_source(source_id, source)
          rescue ::SourcesApiClient::ApiError => e
            logger.availability_check("Failed to update Source id:#{source_id} - #{e.message}", :error)
          end

          def update_endpoint(status, error_message)
            if endpoint.nil?
              logger.availability_check("Failed to update Endpoint for Source id:#{source_id}. Endpoint not found", :error)
              return
            end

            endpoint_update = ::SourcesApiClient::Endpoint.new

            endpoint_update.availability_status       = status
            endpoint_update.availability_status_error = error_message.to_s
            endpoint_update.last_checked_at           = check_time
            endpoint_update.last_available_at         = check_time if status == STATUS_AVAILABLE

            sources_api.update_endpoint(endpoint.id, endpoint_update)
          rescue ::SourcesApiClient::ApiError => e
            logger.availability_check("Failed to update Endpoint(ID: #{endpoint.id}) - #{e.message}", :error)
          end

          def update_application(status)
            application_update                   = ::SourcesApiClient::Application.new
            application_update.last_checked_at   = check_time
            application_update.last_available_at = check_time if status == STATUS_AVAILABLE

            sources_api.update_application(application.id, application_update)
          rescue ::SourcesApiClient::ApiError => e
            logger.availability_check("Failed to update Application id: #{application.id} - #{e.message}", :error)
          end

          def check_time
            @check_time ||= Time.now.utc
          end
        end
      end
    end
  end
end
