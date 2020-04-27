require "config"
require "topological_inventory/providers/common/heartbeat"

module TopologicalInventory
  module Providers
    module Common
      class CollectorsPool
        include TopologicalInventory::Providers::Common::HeartbeatQueue

        SECRET_FILENAME = "credentials".freeze

        def initialize(config_name, metrics, collector_poll_time: 60, thread_pool_size: 2)
          self.config_name         = config_name
          self.collector_status    = Concurrent::Map.new
          self.metrics             = metrics
          self.collector_poll_time = collector_poll_time
          self.secrets             = nil
          self.thread_pool         = Concurrent::FixedThreadPool.new(thread_pool_size)
          self.updated_at          = {}
          self.heartbeat_queue     = heartbeat('collector_pool')
        end

        def run!
          heartbeat_queue.run_thread

          loop do
            reload_config
            reload_secrets

            # Secret is deployed just after config map, we should wait for it
            queue_collectors if secrets_newer_than_config?

            sleep(5)
          end
        end

        def stop!
          heartbeat_queue.stop
          collectors.each_value(&:stop)

          thread_pool.shutdown
          # Wait for end of collectors to ensure metrics are stopped after them
          thread_pool.wait_for_termination
        end

        protected

        attr_accessor :collectors, :collector_poll_time, :collector_status, :thread_pool, :config_name,
                      :metrics, :secrets, :updated_at, :heartbeat_queue

        def reload_config
          config_file = File.join(path_to_config, "#{sanitize_filename(config_name)}.yml")
          raise "Configuration file #{config_file} doesn't exist" unless File.exist?(config_file)

          ::Config.load_and_set_settings(config_file)
        end

        def reload_secrets
          path = File.join(path_to_secrets, SECRET_FILENAME)
          raise "Secrets file missing at #{path}" unless File.exists?(path)
          file         = File.read(path)
          self.secrets = JSON.parse(file)
        end

        # @param [Hash] source from Settings
        # @return [Hash|nil] {"username":, "password":}
        def secrets_for_source(source)
          secrets[source.source]
        end

        def queue_collectors
          ::Settings.sources.to_a.each do |source|
            # Skip if collector is running/queued or just finished
            next if queued_or_updated_recently?(source)

            # Check if secrets for this source are present
            next if (source_secret = secrets_for_source(source)).nil?

            # Check if necessary endpoint/auth data are not blank (provider specific)
            next unless source_valid?(source, source_secret)

            collector_status[source.source] = {:status => :queued}
            # Add source to collector's queue
            thread_pool.post do
              begin
                collector = new_collector(source, source_secret, heartbeat_queue)
                collector.collect!
              ensure
                collector_status[source.source] = {:status => :ready, :last_updated_at => Time.now}
              end
            end
          end
        end

        def queued_or_updated_recently?(source)
          return false if collector_status[source.source].nil?
          return true if collector_status[source.source][:status] == :queued

          if (last_updated_at = collector_status[source.source][:last_updated_at]).nil?
            # should never happen
            last_updated_at = Time.now
            collector_status[source.source] = {:status => :ready, :last_updated_at => last_updated_at}
          end

          updated_recently = last_updated_at > Time.now - collector_poll_time.to_i
          heartbeat_queue.queue_tick if updated_recently

          updated_recently
        end

        def secrets_newer_than_config?
          return false if ::Settings.updated_at.nil? || secrets["updated_at"].nil?

          updated_at[:config] = Time.parse(::Settings.updated_at)
          updated_at[:secret] = Time.parse(secrets["updated_at"])

          logger.info("Reloading Sources data => Config [updated_at: #{updated_at[:config].to_s}], Secrets [updated at: #{updated_at[:secret]}]") if updated_at[:config] <= updated_at[:secret]

          updated_at[:config] <= updated_at[:secret]
        end

        def source_valid?(source, secret)
          true
        end

        def path_to_config
          raise NotImplementedError, "#{__method__} must be implemented in a subclass"
        end

        def path_to_secrets
          raise NotImplementedError, "#{__method__} must be implemented in a subclass"
        end

        def sanitize_filename(filename)
          # Remove any character that aren't 0-9, A-Z, or a-z, / or -
          filename.gsub(/[^0-9A-Z\/\-]/i, '_')
        end

        def new_collector(source, source_secret, heartbeat_queue = nil)
          raise NotImplementedError, "#{__method__} must be implemented in a subclass"
        end
      end
    end
  end
end
