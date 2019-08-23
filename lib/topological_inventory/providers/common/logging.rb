require "manageiq/loggers"

module TopologicalInventory
  module Providers
    module Common
      class << self
        attr_writer :logger
      end

      def self.logger
        @logger ||= ManageIQ::Loggers::Container.new
        @logger
      end

      module Logging
        def logger
          TopologicalInventory::Providers::Common.logger
        end
      end
    end
  end
end
