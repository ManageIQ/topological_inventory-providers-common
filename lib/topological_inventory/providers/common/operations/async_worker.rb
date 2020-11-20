require "topological_inventory/providers/common/logging"
require "topological_inventory/providers/common/mixins/statuses"
require "topological_inventory/providers/common/operations/health_check"

module TopologicalInventory
  module Providers
    module Common
      module Operations
        class AsyncWorker
          include Logging
          include TopologicalInventory::Providers::Common::Mixins::Statuses

          def initialize(processor, queue: nil, metrics: nil)
            @processor = processor
            @queue     = queue || Queue.new
            @metrics   = metrics
          end

          def start
            return if thread.present?

            @thread = Thread.new { listen }
          end

          def stop
            thread&.exit
          end

          def enqueue(msg)
            queue << msg
          end

          def listen
            loop do
              # the queue thread waits for a message to come during `Queue#pop`
              msg = queue.pop
              process_message(msg)
            end
          end

          private

          attr_reader :thread, :queue, :processor, :metrics

          def process_message(message)
            result = processor.process!(message, metrics)
            metrics&.record_operation(message.message, :status => result)
          rescue => err
            model, method = message.message.to_s.split(".")
            logger.error("#{model}##{method}: async worker failure: #{err.cause}\n#{err}\n#{err.backtrace.join("\n")}")
            metrics&.record_operation(message.message, :status => operation_status[:error])
          ensure
            message.ack
            TopologicalInventory::Providers::Common::Operations::HealthCheck.touch_file
            logger.debug("Operations::AsyncWorker queue length: #{queue.length}") if queue.length >= 20 && queue.length % 5 == 0
          end
        end
      end
    end
  end
end
