require "more_core_extensions/core_ext/module/cache_with_timeout"
require "manageiq-messaging"
require "topological_inventory/providers/common/clowder_config"

module TopologicalInventory
  module Providers
    module Common
      class MessagingClient
        # Kafka host name
        attr_accessor :queue_host
        # Kafka port
        attr_accessor :queue_port

        def initialize
          self.queue_host = TopologicalInventory::Providers::Common::ClowderConfig.instance["kafkaHost"]
          self.queue_port = TopologicalInventory::Providers::Common::ClowderConfig.instance["kafkaPort"].to_i
        end

        def self.default
          @@default ||= new
        end

        def self.configure
          if block_given?
            yield(default)
          else
            default
          end
        end

        cache_with_timeout(:client) do
          ManageIQ::Messaging::Client.open(:protocol => :Kafka, :host => default.queue_host, :port => default.queue_port)
        end

        def client
          self.class.client
        end
      end
    end
  end
end
