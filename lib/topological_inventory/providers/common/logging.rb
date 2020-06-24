require "manageiq/loggers"

module TopologicalInventory
  module Providers
    module Common
      module LoggingFunctions
        def collecting(status, source, entity_type, refresh_state_uuid, total_parts = nil)
          msg = "[#{status.to_s.upcase}] Collecting #{entity_type}"
          msg += ", :total parts => #{total_parts}" if total_parts.present?
          msg += ", :source_uid => #{source}, :refresh_state_uuid => #{refresh_state_uuid}"
          info(msg)
        end

        def collecting_error(source, entity_type, refresh_state_uuid, exception)
          msg = "[ERROR] Collecting #{entity_type}, :source_uid => #{source}, :refresh_state_uuid => #{refresh_state_uuid}"
          msg += ":message => #{exception.message}\n#{exception.backtrace.join("\n")}"
          error(msg)
        end

        def sweeping(status, source, sweep_scope, refresh_state_uuid)
          msg = "[#{status.to_s.upcase}] Sweeping inactive records, :sweep_scope => #{sweep_scope}, :source_uid => #{source}, :refresh_state_uuid => #{refresh_state_uuid}"
          info(msg)
        end

        def availability_check(message, severity = :info)
          log_with_prefix("Source#availability_check", message, severity)
        end

        def log_with_prefix(prefix, message, severity)
          send(severity, "#{prefix} - #{message}") if respond_to?(severity)
        end
      end

      class Logger < ManageIQ::Loggers::CloudWatch
        def self.new(*args)
          super.tap { |logger| logger.extend(TopologicalInventory::Providers::Common::LoggingFunctions) }
        end
      end

      class << self
        attr_writer :logger
      end

      def self.logger
        @logger ||= TopologicalInventory::Providers::Common::Logger.new
      end

      module Logging
        def logger
          TopologicalInventory::Providers::Common.logger
        end
      end
    end
  end
end
