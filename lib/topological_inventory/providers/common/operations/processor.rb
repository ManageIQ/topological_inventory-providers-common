require "topological_inventory/providers/common/operations/topology_api_client"

module TopologicalInventory
  module Providers
    module Common
      module Operations
        class Processor
          include Logging
          include TopologyApiClient

          SLEEP_POLL = 10
          POLL_TIMEOUT = 1800

          def self.process!(message)
            model, method = message.headers['message_type'].to_s.split(".")
            new(model, method, message.payload).process
          end

          # @param payload [Hash] https://github.com/ManageIQ/topological_inventory-api/blob/master/app/controllers/api/v0/service_plans_controller.rb#L32-L41
          def initialize(model, method, payload, metrics = nil)
            self.model           = model
            self.method          = method
            self.params          = payload["params"]
            self.identity        = payload["request_context"]
            self.metrics         = metrics
          end

          def process
            logger.info("Processing #{model}##{method} [#{params}]...")
            result = order_service(params)
            logger.info("Processing #{model}##{method} [#{params}]...Complete")

            result
          end

          private

          attr_accessor :identity, :model, :method, :metrics, :params

          def endpoint_client(source_id, task_id, identity)
            raise NotImplementedError, "#{__method__} must be implemented in a subclass as kind of TopologicalInventory::Providers::Common::EndpointClient class"
          end

          def order_service(params)
            task_id, service_offering_id, service_plan_id, order_params = params.values_at("task_id", "service_offering_id", "service_plan_id", "order_params")

            service_plan     = topology_api_client.show_service_plan(service_plan_id) if service_plan_id.present?
            service_offering_id = service_plan.service_offering_id if service_offering_id.nil? && service_plan.present?
            service_offering = topology_api_client.show_service_offering(service_offering_id)

            source_id        = service_offering.source_id
            client = endpoint_client(source_id, task_id, identity)

            logger.info("Ordering #{service_offering.name}...")
            remote_service_instance = client.order_service(service_offering, service_plan.presence, order_params)
            logger.info("Ordering #{service_offering.name}...Complete")

            poll_order_complete_thread(task_id, source_id, remote_service_instance)
          rescue StandardError => err
            metrics&.record_error
            logger.error("[Task #{task_id}] Ordering error: #{err}\n#{err.backtrace.join("\n")}")
            update_task(task_id, :state => "completed", :status => "error", :context => {:error => err.to_s})
          end

          def poll_order_complete_thread(task_id, source_id, remote_svc_instance)
            Thread.new do
              begin
                poll_order_complete(task_id, source_id, remote_svc_instance)
              rescue StandardError => err
                logger.error("[Task #{task_id}] Waiting for complete: #{err}\n#{err.backtrace.join("\n")}")
                update_task(task_id, :state => "completed", :status => "warn", :context => {:error => err.to_s})
              end
            end
          end

          def poll_order_complete(task_id, source_id, remote_svc_instance)
            client = endpoint_client(source_id, task_id, identity)

            context = {
              :service_instance => {
                :source_id  => source_id,
                :source_ref => client.source_ref_of(remote_svc_instance)
              }
            }

            remote_svc_instance = client.wait_for_provision_complete(task_id, remote_svc_instance, context)

            if client.provisioned_successfully?(remote_svc_instance)
              if (service_instance = load_topological_svc_instance(source_id, client.source_ref_of(remote_svc_instance))).present?
                context[:service_instance][:id] = service_instance.id
                context[:service_instance][:url] = svc_instance_url(service_instance)
              else
                logger.warn("Failed to get service_instance API URL (endpoint's service instance: #{remote_svc_instance.inspect})")
              end
            end
            update_task(task_id, :state => "completed", :status => client.task_status_for(remote_svc_instance), :context => context)
          end

          def load_topological_svc_instance(source_id, source_ref)
            api = topology_api_client.api_client

            count = 0
            timeout_count = POLL_TIMEOUT / SLEEP_POLL

            header_params = { 'Accept' => api.select_header_accept(['application/json']) }
            query_params = { :'source_id' => source_id, :'source_ref' => source_ref }
            return_type = 'ServiceInstancesCollection'

            service_instance = nil
            loop do
              data, _status_code, _headers = api.call_api(:GET, "/service_instances",
                                                          :header_params => header_params,
                                                          :query_params  => query_params,
                                                          :auth_names    => ['UserSecurity'],
                                                          :return_type   => return_type)

              service_instance = data.data&.first if data.meta.count > 0
              break if service_instance.present?

              break if (count += 1) >= timeout_count

              sleep(SLEEP_POLL) # seconds
            end

            if service_instance.nil?
              logger.error("Failed to find service_instance by source_id [#{source_id}] source_ref [#{source_ref}]")
            end

            service_instance
          end
        end
      end
    end
  end
end
