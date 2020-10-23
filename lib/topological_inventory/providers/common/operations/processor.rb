require "topological_inventory/providers/common/logging"
require "topological_inventory/providers/common/mixins/statuses"
require "topological_inventory/providers/common/mixins/topology_api"

module TopologicalInventory
  module Providers
    module Common
      module Operations
        class Processor
          include Logging
          include Mixins::Statuses
          include Mixins::TopologyApi

          def self.process!(message, metrics)
            new(message, metrics).process
          end

          def initialize(message, metrics)
            self.message            = message
            self.metrics            = metrics
            self.model, self.method = message.message.split(".")

            self.params   = message.payload["params"]
            self.identity = message.payload["request_context"]
          end

          def process
            logger.info(status_log_msg)
            impl = operation_class&.new(params, identity, metrics)
            if impl&.respond_to?(method)
              with_time_measure do
                result = impl.send(method)

                logger.info(status_log_msg("Complete"))
                result
              end
            else
              logger.warn(status_log_msg("Not Implemented!"))
              complete_task("not implemented") if params["task_id"]
              operation_status[:not_implemented]
            end
          rescue StandardError, NotImplementedError => e
            complete_task(e.message) if params["task_id"]
            raise
          end

          private

          attr_accessor :message, :identity, :model, :method, :metrics, :params

          def operation_class
            raise NotImplementedError, "#{__method__} must be implemented in a subclass"
          end

          def with_time_measure
            if metrics.present?
              metrics.record_operation_time(message.message) { yield }
            else
              yield
            end
          end

          def complete_task(msg, status = "error")
            update_task(params["task_id"],
                        :state   => "completed",
                        :status  => status,
                        :context => {:error => "#{model}##{method} - #{msg}"})
          end

          def status_log_msg(status = nil)
            "Processing #{model}##{method} [#{params}]...#{status}"
          end
        end
      end
    end
  end
end
