require "benchmark"
require "prometheus_exporter"
require "prometheus_exporter/server"
require "prometheus_exporter/client"
require "prometheus_exporter/instrumentation"
require "topological_inventory/providers/common/mixins/statuses"

module TopologicalInventory
  module Providers
    module Common
      class Metrics
        include TopologicalInventory::Providers::Common::Mixins::Statuses

        ERROR_COUNTER_MESSAGE = "total number of errors".freeze
        ERROR_TYPES = %i[general].freeze
        OPERATIONS  = %w[].freeze

        def initialize(port = 9394)
          return if port == 0

          configure_server(port)
          configure_metrics

          init_counters
        end

        def stop_server
          @server&.stop
        end

        def record_error(type = :general)
          @error_counter&.observe(1, :type => type.to_s)
        end

        def record_refresh_timing(labels = {}, &block)
          record_time(@refresh_timer, labels, &block)
        end

        def record_operation(name, labels = {})
          @status_counter&.observe(1, (labels || {}).merge(:name => name))
        end

        def record_operation_time(name, labels = {}, &block)
          record_time(@duration_seconds, (labels || {}).merge(:name => name), &block)
        end

        # Common method for gauge
        def record_gauge(metric, opt, value: nil, labels: {})
          case opt
          when :set then
            metric&.observe(value.to_i, labels)
          when :add then
            metric&.increment(labels)
          when :remove then
            metric&.decrement(labels)
          end
        end

        # Common method for histogram
        def record_time(metric, labels = {})
          result = nil
          time = Benchmark.realtime { result = yield }
          metric&.observe(time, labels)
          result
        end

        private

        # Set all values to 0 (otherwise the counter is undefined)
        def init_counters
          self.class::ERROR_TYPES.each do |err_type|
            @error_counter&.observe(0, :type => err_type)
          end

          self.class::OPERATIONS.each do |op|
            operation_status.each_key do |status|
              @status_counter&.observe(0, :name => op, :status => status.to_s)
            end
          end
        end

        def configure_server(port)
          @server = PrometheusExporter::Server::WebServer.new(:port => port)
          @server.start

          PrometheusExporter::Client.default = PrometheusExporter::LocalClient.new(:collector => @server.collector)
        end

        def configure_metrics
          PrometheusExporter::Instrumentation::Process.start
          PrometheusExporter::Metric::Base.default_prefix = default_prefix

          @duration_seconds = PrometheusExporter::Metric::Histogram.new('duration_seconds', 'Duration of processed operation')
          @refresh_timer = PrometheusExporter::Metric::Histogram.new('refresh_time', 'Duration of full refresh')
          @error_counter = PrometheusExporter::Metric::Counter.new('errors_total', ERROR_COUNTER_MESSAGE)
          @status_counter = PrometheusExporter::Metric::Counter.new('status_counter', 'number of processed operations')

          [@duration_seconds, @refresh_timer, @error_counter, @status_counter].each do |metric|
            @server.collector.register_metric(metric)
          end
        end

        def default_prefix
          raise NotImplementedError, "#{__method__} must be implemented in a subclass"
        end
      end
    end
  end
end
