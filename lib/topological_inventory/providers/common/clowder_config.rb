require 'clowder-common-ruby'
require 'singleton'

module TopologicalInventory
  module Providers
    module Common
      class ClowderConfig
        include Singleton

        def self.clowder_enabled?
          ::ClowderCommonRuby::Config.clowder_enabled?
        end

        def self.instance
          @instance ||= {}.tap do |options|
            if clowder_enabled?
              config                        = ::ClowderCommonRuby::Config.load
              options["awsAccessKeyId"]     = config.logging.cloudwatch.accessKeyId
              options["awsRegion"]          = config.logging.cloudwatch.region
              options["awsSecretAccessKey"] = config.logging.cloudwatch.secretAccessKey
              broker                        = config.kafka.brokers.first
              options["kafkaHost"]          = broker.hostname
              options["kafkaPort"]          = broker.port

              options["kafkaTopics"] = {}.tap do |topics|
                config.kafka.topics.each do |topic|
                  topics[topic.requestedName.to_s] = topic.name.to_s
                end
              end
              options["logGroup"]    = config.logging.cloudwatch.logGroup
              options["metricsPort"] = config.metricsPort
              options["metricsPath"] = config.metricsPath # not supported by PrometheusExporter
            else
              options["awsAccessKeyId"]     = ENV['CW_AWS_ACCESS_KEY_ID']
              options["awsRegion"]          = 'us-east-1'
              options["awsSecretAccessKey"] = ENV['CW_AWS_SECRET_ACCESS_KEY']
              options["kafkaBrokers"]       = ["#{ENV['QUEUE_HOST']}:#{ENV['QUEUE_PORT']}"]
              options["kafkaHost"]          = ENV['QUEUE_HOST'] || 'localhost'
              options["kafkaPort"]          = (ENV['QUEUE_PORT'] || '9092').to_i
              options["kafkaTopics"]        = {}
              options["logGroup"]           = 'platform-dev'
              options["metricsPort"]        = (ENV['METRICS_PORT'] || 9394).to_i
            end
          end
        end

        def self.fill_args_operations(args)
          args[:metrics_port] = instance['metricsPort']
          args[:queue_host]   = instance['kafkaHost']
          args[:queue_port]   = instance['kafkaPort']
          args
        end

        def self.kafka_topic(name)
          instance["kafkaTopics"][name] || name
        end
      end
    end
  end
end

# ManageIQ Message Client depends on these variables
ENV["QUEUE_HOST"] = TopologicalInventory::Providers::Common::ClowderConfig.instance["kafkaHost"]
ENV["QUEUE_PORT"] = TopologicalInventory::Providers::Common::ClowderConfig.instance["kafkaPort"].to_s

# ManageIQ Logger depends on these variables
ENV['CW_AWS_ACCESS_KEY_ID']     = TopologicalInventory::Providers::Common::ClowderConfig.instance["awsAccessKeyId"]
ENV['CW_AWS_SECRET_ACCESS_KEY'] = TopologicalInventory::Providers::Common::ClowderConfig.instance["awsSecretAccessKey"]
