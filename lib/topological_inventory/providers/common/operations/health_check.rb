module TopologicalInventory
  module Providers
    module Common
      module Operations
        class HealthCheck
          HEARTBEAT_FILE = '/tmp/healthy'.freeze

          def self.touch_file
            FileUtils.touch(HEARTBEAT_FILE)
          end
        end
      end
    end
  end
end
