RSpec.describe TopologicalInventory::Providers::Common::Collector do
  let(:collector) do
    collector = described_class.new(source)

    allow(collector).to receive(:ingress_api_client).and_return(client)
    allow(collector).to receive(:logger).and_return(logger)
    allow(logger).to receive(:error)

    collector
  end

  let(:parser) { TopologicalInventory::Providers::Common::Collector::Parser.new }

  let(:source)  { "source_uid" }
  let(:client)  { double }
  let(:logger)  { double }
  let(:refresh_state_uuid) { SecureRandom.uuid }
  let(:refresh_state_part_uuid) { SecureRandom.uuid }
  # based on the default, we can tell how many chunks the saver will break the payload up into
  let(:max_size) { TopologicalInventory::Providers::Common::SaveInventory::Saver::KAFKA_PAYLOAD_MAX_BYTES_DEFAULT }
  let(:multiplier) { 0.75 }

  context "#save_inventory" do
    it "does nothing with empty collections" do
      parts = collector.send(:save_inventory, [], collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, refresh_state_part_uuid)

      expect(parts).to eq 0
    end

    it "saves 1 part if it fits" do
      (multiplier * 1000).floor.times { parser.collections.container_groups.build(:source_ref => "a" * 950) }

      expect(inventory_size(parser.collections.values) / max_size).to eq(0)

      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times
      parts = collector.send(:save_inventory, parser.collections.values, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, refresh_state_part_uuid)
      expect(parts).to eq 1
    end

    it "saves 2 parts if over limit with 1 collection" do
      (multiplier * 2000).floor.times { parser.collections.container_groups.build(:source_ref => "a" * 950) }

      expect(inventory_size(parser.collections.values) / max_size).to eq(1)

      expect(client).to receive(:save_inventory_with_http_info).exactly(2).times
      parts = collector.send(:save_inventory, parser.collections.values, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, refresh_state_part_uuid)
      expect(parts).to eq 2
    end

    it "saves 2 parts if over limit with 2 collections" do
      (multiplier * 1000).floor.times { parser.collections.container_groups.build(:source_ref => "a" * 950) }
      (multiplier * 1000).floor.times { parser.collections.container_nodes.build(:source_ref => "a" * 950) }

      expect(inventory_size(parser.collections.values) / max_size).to eq(1)

      expect(client).to receive(:save_inventory_with_http_info).exactly(2).times
      parts = collector.send(:save_inventory, parser.collections.values, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, refresh_state_part_uuid)
      expect(parts).to eq 2
    end

    it "saves many parts" do
      (multiplier * 1500).floor.times { parser.collections.container_groups.build(:source_ref => "a" * 950) }
      (multiplier * 2000).floor.times { parser.collections.container_nodes.build(:source_ref => "a" * 950) }

      expect(client).to receive(:save_inventory_with_http_info).exactly(4).times
      parts = collector.send(:save_inventory, parser.collections.values, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, refresh_state_part_uuid)
      expect(parts).to eq 4
    end

    it 'raises exception when entity to save is too big' do
      parser.collections.container_groups.build(:source_ref => "a" * (1_000_000 * multiplier))

      expect(inventory_size(parser.collections.values) / max_size).to eq(1)
      # in this case, we first save empty inventory, then the size check fails saving the rest of data
      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times

      expect { collector.send(:save_inventory, parser.collections.values, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, refresh_state_part_uuid) }.to(
        raise_error(TopologicalInventory::Providers::Common::SaveInventory::Exception::EntityTooLarge)
      )
    end

    it 'raises exception when entity of second collection is too big' do
      (multiplier * 1000).floor.times { parser.collections.container_groups.build(:source_ref => "a" * 950) }
      parser.collections.container_nodes.build(:source_ref => "a" * (1_000_000 * multiplier))

      expect(inventory_size(parser.collections.values) / max_size).to eq(1)
      # We save the first collection then it fails on saving the second collection
      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times

      expect { collector.send(:save_inventory, parser.collections.values, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, refresh_state_part_uuid) }.to(
        raise_error(TopologicalInventory::Providers::Common::SaveInventory::Exception::EntityTooLarge)
      )
    end

    it 'raises exception when entity of second collection is too big then continues with smaller' do
      (multiplier * 1000).floor.times { parser.collections.container_groups.build(:source_ref => "a" * 950) }
      parser.collections.container_nodes.build(:source_ref => "a" * (1_000_000 * multiplier))
      (multiplier * 1000).floor.times { parser.collections.container_nodes.build(:source_ref => "a" * 950) }

      expect(inventory_size(parser.collections.values) / max_size).to eq(2)
      # We save the first collection then it fails on saving the second collection
      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times

      expect { collector.send(:save_inventory, parser.collections.values, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, refresh_state_part_uuid) }.to(
        raise_error(TopologicalInventory::Providers::Common::SaveInventory::Exception::EntityTooLarge)
      )
    end
  end

  context "#sweep_inventory" do
    it "with nil total parts" do
      expect(client).to receive(:save_inventory_with_http_info).exactly(0).times

      collector.send(:sweep_inventory, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, nil, [])
    end

    it "with empty scope " do
      expect(client).to receive(:save_inventory_with_http_info).exactly(0).times

      collector.send(:sweep_inventory, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, 1, [])
    end

    it "with normal scope " do
      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times

      collector.send(:sweep_inventory, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, 1, [:container_groups])
    end

    it "with normal targeted scope " do
      expect(client).to receive(:save_inventory_with_http_info).exactly(1).times

      collector.send(:sweep_inventory, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, 1, {:container_groups => [{:source_ref => "a"}]})
    end

    it "fails with scope entity too large " do
      expect(client).to receive(:save_inventory_with_http_info).exactly(0).times

      sweep_scope = {:container_groups => [{:source_ref => "a" * (1_000_002 * multiplier)}]}

      expect { collector.send(:sweep_inventory, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, 1, sweep_scope) }.to(
        raise_error(TopologicalInventory::Providers::Common::SaveInventory::Exception::EntityTooLarge)
      )
    end

    it "fails when scope is too big " do
      # We should have also sweep scope chunking, that is if we'll do big targeted refresh and sweeping
      expect(client).to receive(:save_inventory_with_http_info).exactly(0).times

      sweep_scope = {:container_groups => (0..1001 * multiplier).map { {:source_ref => "a" * 1_000} } }

      expect { collector.send(:sweep_inventory, collector.send(:inventory_name), collector.send(:schema_name), refresh_state_uuid, 1, sweep_scope) }.to(
        raise_error(TopologicalInventory::Providers::Common::SaveInventory::Exception::EntityTooLarge)
      )
    end
  end

  def build_inventory(collections)
    TopologicalInventoryIngressApiClient::Inventory.new(
      :name                    => collector.send(:inventory_name),
      :schema                  => TopologicalInventoryIngressApiClient::Schema.new(:name => collector.send(:schema_name)),
      :source                  => source,
      :collections             => collections,
      :refresh_state_uuid      => refresh_state_uuid,
      :refresh_state_part_uuid => refresh_state_part_uuid,
    )
  end

  def inventory_size(collections)
    JSON.generate(build_inventory(collections).to_hash).size
  end
end
