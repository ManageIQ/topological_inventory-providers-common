require "more_core_extensions/core_ext/module/cache_with_timeout"
require "manageiq-messaging"

module TopologicalInventory
  module Providers
    module Common
      class MessagingClient
        # Kafka host name
        attr_accessor :queue_host
        # Kafka port
        attr_accessor :queue_port

        def initialize
          @queue_host = ENV['QUEUE_HOST'] || 'localhost'
          @queue_port = (ENV['QUEUE_PORT'] || 9092).to_i
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
          ManageIQ::Messaging::Client.open(:protocol => :Kafka, :host => @queue_host, :port => @queue_port)
        end

        def client
          self.class.client
        end
      end
    end
  end
end
