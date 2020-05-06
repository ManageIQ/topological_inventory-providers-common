require "active_support/inflector"
require "concurrent"
require "topological_inventory-ingress_api-client"
require "topological_inventory/providers/common/collector/inventory_collection_storage"
require "topological_inventory/providers/common/collector/inventory_collection_wrapper"
require "topological_inventory/providers/common/collector/parser"
require "topological_inventory/providers/common/save_inventory/saver"

module TopologicalInventory
  module Providers
    module Common
      class Collector
        # @param poll_time [Integer] Waiting between collecting loops. Irrelevant for standalone_mode: true
        # @param standalone_mode [Boolean] T/F if collector is created by collectors_pool
        def initialize(source, default_limit: 1_000, poll_time: 30, standalone_mode: true)
          self.collector_threads = Concurrent::Map.new
          self.finished          = Concurrent::AtomicBoolean.new(false)
          self.poll_time         = poll_time
          self.limits            = Hash.new(default_limit)
          self.queue             = Queue.new
          self.source            = source
          self.standalone_mode   = standalone_mode
        end

        def collect!
          start_collector_threads

          until finished? do
            ensure_collector_threads

            notices = []
            notices << queue.pop until queue.empty?

            targeted_refresh(notices) unless notices.empty?

            standalone_mode ? sleep(poll_time) : stop
          end
        end

        def stop
          finished.value = true
        end

        protected

        attr_accessor :collector_threads, :finished, :limits,
                      :poll_time, :queue, :source, :standalone_mode

        def finished?
          finished.value
        end

        def entity_types
          endpoint_types.flat_map { |endpoint| send("#{endpoint}_entity_types") }
        end

        # Should be overriden by subclass
        # Entity types collected from endpoints
        def endpoint_types
          %w()
        end

        def start_collector_threads
          entity_types.each do |entity_type|
            next if collector_threads[entity_type]&.alive?

            collector_threads[entity_type] = start_collector_thread(entity_type)
          end
        end

        def ensure_collector_threads
          start_collector_threads
        end

        def start_collector_thread(entity_type)
          connection = connection_for_entity_type(entity_type)
          return if connection.nil?

          Thread.new do
            collector_thread(connection, entity_type)
          end
        end

        # Connection to endpoint for each entity type
        def connection_for_entity_type(_entity_type)
          raise NotImplementedError
        end

        # Thread's main for collecting one entity type's data
        def collector_thread(_connection, _entity_type)
          raise NotImplementedError
        end

        # @optional
        # Listen to notices from threads
        def targeted_refresh(notices)
        end

        # @param refresh_state_part_collected_at [Time] when this payload is collected (for [Core]:RefreshStatePart)
        # @param refresh_state_part_sent_at [Time] when this payload is sent (for [Core]:RefreshStatePart)
        def save_inventory(collections,
                           inventory_name,
                           schema,
                           refresh_state_uuid = nil,
                           refresh_state_part_uuid = nil,
                           refresh_state_part_collected_at = nil,
                           refresh_state_part_sent_at = Time.now.utc)
          return 0 if collections.empty?

          SaveInventory::Saver.new(:client => ingress_api_client, :logger => logger).save(
            :inventory => TopologicalInventoryIngressApiClient::Inventory.new(
              :name                            => inventory_name,
              :schema                          => TopologicalInventoryIngressApiClient::Schema.new(:name => schema),
              :source                          => source,
              :collections                     => collections,
              :refresh_state_uuid              => refresh_state_uuid,
              :refresh_state_part_uuid         => refresh_state_part_uuid,
              :refresh_state_part_collected_at => refresh_state_part_collected_at,
              :refresh_state_part_sent_at      => refresh_state_part_sent_at
            )
          )
        rescue => e
          response_body    = e.response_body if e.respond_to? :response_body
          response_headers = e.response_headers if e.respond_to? :response_headers
          logger.error("Error when sending payload to Ingress API. Error message: #{e.message}. Body: #{response_body}. Header: #{response_headers}")
          raise e
        end

        # @param refresh_state_started_at [Time] when collecting of this entity type is started (for [Core]:RefreshState)
        # @param refresh_state_sent_at [Time] when this payload is sent (for [Core]:RefreshState)
        def sweep_inventory(inventory_name,
                            schema,
                            refresh_state_uuid,
                            total_parts,
                            sweep_scope,
                            refresh_state_started_at = nil,
                            refresh_state_sent_at = Time.now.utc)
          return if !total_parts || sweep_scope.empty?

          SaveInventory::Saver.new(:client => ingress_api_client, :logger => logger).save(
            :inventory => TopologicalInventoryIngressApiClient::Inventory.new(
              :name                     => inventory_name,
              :schema                   => TopologicalInventoryIngressApiClient::Schema.new(:name => schema),
              :source                   => source,
              :collections              => [],
              :refresh_state_uuid       => refresh_state_uuid,
              :total_parts              => total_parts,
              :sweep_scope              => sweep_scope,
              :refresh_state_started_at => refresh_state_started_at,
              :refresh_state_sent_at    => refresh_state_sent_at
            )
          )
        rescue => e
          response_body    = e.response_body if e.respond_to? :response_body
          response_headers = e.response_headers if e.respond_to? :response_headers
          logger.error("Error when sending payload to Ingress API. Error message: #{e.message}. Body: #{response_body}. Header: #{response_headers}")
          raise e
        end

        def inventory_name
          "Default"
        end

        def schema_name
          "Default"
        end

        def ingress_api_client
          TopologicalInventoryIngressApiClient::DefaultApi.new
        end

        def log_external_url(url)
          logger.info("[EXTERNAL URL] #{url}")
        end
      end
    end
  end
end
