require "config"

module TopologicalInventory
  module Providers
    module Common
      class CollectorsPool
        SECRET_FILENAME = "credentials".freeze

        def initialize(config_name, metrics, poll_time: 10)
          self.collectors        = {}
          self.collector_threads = {}
          self.config_name       = config_name
          self.metrics           = metrics
          self.poll_time         = poll_time
          self.secrets           = nil
          self.updated_at        = {}
        end

        def run!
          loop do
            reload_config
            reload_secrets

            # Secret is deployed just after config,
            # so we should wait for it
            if secrets_newer_than_config?
              remove_old_collectors
              add_new_collectors
            end

            sleep(poll_time)
          end
        end

        def stop!
          collectors.each_value(&:stop)

          # Wait for end of collectors to ensure metrics are stopped after them
          collector_threads.each_value { |thread| thread.kill unless thread.join(30) }
        end

        protected

        attr_accessor :collectors, :collector_threads, :config_name, :metrics, :poll_time, :secrets, :updated_at

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

        def add_new_collectors
          ::Settings.sources.to_a.each do |source|
            next unless collectors[source.source].nil?
            next if (source_secret = secrets_for_source(source)).nil?

            # Check if necessary endpoint/auth data are not blank (provider specific)
            next unless source_valid?(source, source_secret)

            collector = new_collector(source, source_secret)
            collectors[source.source] = collector
            thread = Thread.new { collector.collect! }
            collector_threads[source.source] = thread
          end
        end

        def remove_old_collectors
          requested_uids = ::Settings.sources.to_a.collect(&:source)
          existing_uids  = collectors.keys

          (existing_uids - requested_uids).each do |source_uid|
            collector = collectors.delete(source_uid)
            collector_threads.delete(source_uid)
            collector&.stop
          end
        end

        def secrets_newer_than_config?
          return false if ::Settings.updated_at.nil? || secrets["updated_at"].nil?

          updated_at[:config] = Time.parse(::Settings.updated_at)
          updated_at[:secret] = Time.parse(secrets["updated_at"])

          logger.info("Updated at: Config load: #{updated_at[:config].to_s}, Secret load: #{updated_at[:secret]}")

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

        def new_collector(source, source_secret)
          raise NotImplementedError, "#{__method__} must be implemented in a subclass"
        end
      end
    end
  end
end
