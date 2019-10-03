require "topological_inventory/providers/common/logging"

module TopologicalInventory
  module Providers
    module Common
      module Operations
        class Processor
          include Logging

          def self.process!(message)
            model, method = message.message.to_s.split(".")
            new(model, method, message.payload).process
          end

          # @param payload [Hash] https://github.com/ManageIQ/topological_inventory-api/blob/master/app/controllers/api/v0/service_plans_controller.rb#L32-L41
          def initialize(model, method, payload, metrics = nil)
            self.model           = model
            self.method          = method
            self.params          = payload["params"]
            self.identity        = payload["request_context"]
            self.metrics         = metrics
          end

          def process
            logger.info("Processing #{model}##{method} [#{params}]...")

            impl = operation_model&.new(params, identity)
            result = impl&.send(method) if impl&.respond_to?(method)

            logger.info("Processing #{model}##{method} [#{params}]...Complete")
            result
          end

          protected

          attr_accessor :identity, :model, :method, :metrics, :params

          def operation_model
            "#{Operations}::#{model}".safe_constantize
          end
        end
      end
    end
  end
end
