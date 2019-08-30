module TopologicalInventory
  module Providers
    module Common
      class Collector
        class InventoryCollectionStorage
          attr_accessor :data

          delegate :values, :to => :data

          def initialize
            @data = {}
          end

          def add_collection(name, overwrite: true)
            return @data[name] if !@data[name].nil? && !overwrite

            if ingress_api_model_exists?(name)
              @data[name] ||= InventoryCollectionWrapper.new(:name => name)
            else
              raise NameError, "TopologicalInventoryIngressApiClient::#{name.to_s.classify} doesn't exist"
            end
          end

          # Creates collection automatically
          def [](name)
            add_collection(name, :overwrite => false)
          end

          # @return [Array<Symbol>] array of InventoryCollection object names of the persister
          def inventory_collections_names
            @data.keys
          end

          def method_missing(method_name, *arguments, &block)
            add_collection(method_name, :overwrite => false) # init collection if not exist

            if inventory_collections_names.include?(method_name)
              self.class.define_collections_reader(method_name)
              send(method_name)
            else
              super
            end
          end

          # @return [Boolean] true if InventoryCollection with passed method_name name is defined
          def respond_to_missing?(method_name, _include_private = false)
            ingress_api_model_exists?(method_name) || super
          end

          protected

          def ingress_api_model_exists?(method_name)
            class_name = "TopologicalInventoryIngressApiClient::#{method_name.to_s.classify}"

            # nil test is not enough due to sometimes weird namespace autoloading
            class_name.safe_constantize.to_s == class_name
          end

          # Defines a new attr reader returning InventoryCollection object
          def self.define_collections_reader(collection_key)
            define_method(collection_key) do
              add_collection(collection_key, :overwrite => false)
            end
          end
        end
      end
    end
  end
end