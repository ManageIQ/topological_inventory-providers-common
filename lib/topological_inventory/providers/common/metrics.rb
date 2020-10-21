require "benchmark"
require "prometheus_exporter"
require "prometheus_exporter/server"
require "prometheus_exporter/client"
require "prometheus_exporter/instrumentation"

module TopologicalInventory
  module Providers
    module Common
      class Metrics
        ERROR_COUNTER_MESSAGE = "total number of errors".freeze

        def initialize(port = 9394)
          return if port == 0

          configure_server(port)
          configure_metrics
        end

        def stop_server
          @server&.stop
        end

        def record_error(type = :general)
          @error_counter&.observe(1, :type => type.to_s)
        end

        def record_operation(name, labels = {})
          @status_counter&.observe(1, labels.merge(:name => name))
        end

        def record_operation_time(name, labels = {})
          record_time(@duration_seconds, labels.merge(:name => name))
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
          time = Benchmark.realtime { yield }
          metric&.observe(time, labels)
        end

        private

        def configure_server(port)
          @server = PrometheusExporter::Server::WebServer.new(:port => port)
          @server.start

          PrometheusExporter::Client.default = PrometheusExporter::LocalClient.new(:collector => @server.collector)
        end

        def configure_metrics
          PrometheusExporter::Instrumentation::Process.start
          PrometheusExporter::Metric::Base.default_prefix = default_prefix

          @duration_seconds = PrometheusExporter::Metric::Histogram.new('duration_seconds', 'Duration of processed operation')
          @error_counter = PrometheusExporter::Metric::Counter.new("error", ERROR_COUNTER_MESSAGE)
          @status_counter = PrometheusExporter::Metric::Counter.new('status_counter', 'number of processed operations')

          [@duration_seconds, @error_counter, @status_counter].each do |metric|
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
