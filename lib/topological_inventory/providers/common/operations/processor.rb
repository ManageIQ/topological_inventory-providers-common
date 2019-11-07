require "topological_inventory/providers/common/logging"
require "topological_inventory-api-client"
require "topological_inventory/providers/common/operations/topology_api_client"

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
            if impl&.respond_to?(method)
              result = impl&.send(method) if impl&.respond_to?(method)

              logger.info("Processing #{model}##{method} [#{params}]...Complete")
              result
            else
              logger.warn("Processing #{model}##{method} [#{params}]...Not Implemented!")
              if params['task_id']
                update_task(params['task_id'], :state => "completed", :status => "error", :context => { :error => "#{model}##{method} Not Implemented"})
              end
            end
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
