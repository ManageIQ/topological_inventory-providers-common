require "topological_inventory/providers/common/save_inventory/exception"

module TopologicalInventory
  module Providers
    module Common
      module SaveInventory
        class Saver
          # As defined in:
          # https://github.com/zendesk/ruby-kafka/blob/02f7e2816e1130c5202764c275e36837f57ca4af/lib/kafka/protocol/message.rb#L11-L17
          # There is at least 112 bytes that are added as a message header, so we need to keep room for that. Lets make
          # it 200 bytes, just for sure.
          KAFKA_RESERVED_HEADER_SIZE = 200

          def initialize(client:, logger:, max_bytes: 1_000_000)
            @client    = client
            @logger    = logger
            @max_bytes = max_bytes - KAFKA_RESERVED_HEADER_SIZE
          end

          attr_reader :client, :logger, :max_bytes

          # @return [Integer] A total number of parts that the payload was divided into
          def save(data)
            inventory = data[:inventory].to_hash

            inventory_json = JSON.generate(inventory)
            if inventory_json.size < max_bytes
              save_inventory(inventory_json)
              return 1
            else
              # GC can clean this up
              inventory_json = nil
              return save_payload_in_batches(inventory)
            end
          end

          private

          def save_payload_in_batches(inventory)
            parts         = 0
            new_inventory = build_new_inventory(inventory)

            inventory[:collections].each do |collection|
              new_collection = build_new_collection(collection)

              data = collection[:data].map { |x| JSON.generate(x) }
              # Lets compute sizes of the each data item, plus 1 byte for comma
              data_sizes = data.map { |x| x.size + 1 }

              # Size of the current inventory and new_collection wrapper, plus 2 bytes for array signs
              wrapper_size = JSON.generate(new_inventory).size + JSON.generate(new_collection).size + 2
              total_size   = wrapper_size
              counter      = 0
              data_sizes.each do |data_size|
                counter    += 1
                total_size += data_size

                if total_size > max_bytes
                  # Remove the last data part, that caused going over the max limit
                  counter -= 1

                  # Add the entities to new collection, so the total size is below max
                  if counter > 0
                    new_collection[:data] = collection[:data].shift(counter)
                    new_inventory[:collections] << new_collection
                  end

                  # Save the current batch
                  serialize_and_save_inventory(new_inventory)
                  parts += 1

                  # Create new data containers for a new batch
                  new_inventory  = build_new_inventory(inventory)
                  new_collection = build_new_collection(collection)
                  wrapper_size   = JSON.generate(new_inventory).size + JSON.generate(new_collection).size + 2

                  # Start with the data part we've removed from the currently saved payload
                  total_size = wrapper_size + data_size
                  counter    = 1
                end
              end

              # Store the rest of the collection
              new_collection[:data] = collection[:data].shift(counter)
              new_inventory[:collections] << new_collection
            end

            # save the rest
            serialize_and_save_inventory(new_inventory)
            parts += 1

            return parts
          end

          def save_inventory(inventory_json)
            client.save_inventory_with_http_info(inventory_json)
          end

          def serialize_and_save_inventory(inventory)
            payload = JSON.generate(inventory)
            if payload.size > max_bytes
              raise Exception::EntityTooLarge,
                    "Entity is bigger than total limit and can't be split: #{payload}"
            end

            # Save the current batch
            save_inventory(payload)
          end

          def build_new_collection(collection)
            {:name => collection[:name], :data => []}
          end

          def build_new_inventory(inventory)
            new_inventory                           = inventory.clone
            new_inventory[:refresh_state_part_uuid] = SecureRandom.uuid
            new_inventory[:collections]             = []
            new_inventory
          end
        end
      end
    end
  end
end
