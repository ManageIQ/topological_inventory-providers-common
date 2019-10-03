module TopologicalInventory
  module Providers
    module Common
      module Operations
        module Core
          module ServiceOrderMixin
            SLEEP_POLL = 10
            POLL_TIMEOUT = 1800

            def order
              task_id, service_offering_id, service_plan_id, order_params = params.values_at("task_id", "service_offering_id", "service_plan_id", "order_params")

              service_plan     = topology_api_client.show_service_plan(service_plan_id.to_s) if service_plan_id.present?
              service_offering_id = service_plan.service_offering_id if service_offering_id.nil? && service_plan.present?
              service_offering = topology_api_client.show_service_offering(service_offering_id.to_s)

              source_id        = service_offering.source_id
              client = endpoint_client(source_id, task_id, identity)

              logger.info("Ordering #{service_offering.name}...")
              remote_service_instance = client.order_service(service_offering, service_plan.presence, order_params)
              logger.info("Ordering #{service_offering.name}...Complete")

              poll_order_complete_thread(task_id, source_id, remote_service_instance)
            rescue StandardError => err
              # metrics&.record_error
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
              task_status = client.task_status_for(remote_svc_instance)

              if client.provisioned_successfully?(remote_svc_instance)
                if (service_instance = load_topological_svc_instance(source_id, client.source_ref_of(remote_svc_instance))).present?
                  context[:service_instance][:id] = service_instance.id
                  context[:service_instance][:url] = service_instance.external_url
                else
                  # If we failed to find the service_instance in the topological-inventory-api
                  # within 30 minutes then something went wrong.
                  task_status = "error"
                  context[:error] = "Failed to find ServiceInstance by source_id [#{source_id}] source_ref [#{remote_svc_instance.id}]"
                end
              end
              update_task(task_id, :state => "completed", :status => task_status, :context => context)
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
end
