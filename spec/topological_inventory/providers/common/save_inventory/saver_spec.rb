require "topological_inventory/providers/common/save_inventory/saver"

RSpec.describe TopologicalInventory::Providers::Common::SaveInventory::Saver do
  let(:client) { instance_double(TopologicalInventoryIngressApiClient::DefaultApi) }
  let(:logger) { double }
  let(:base_args) { {client: client, logger: logger} }

  let(:small_json) { {:test => ["values"]} }
  let(:big_json) { InventorySpecHelper.big_inventory(80_000, 1_000) }

  describe "#save" do
    subject { described_class.new(args).save(:inventory => inventory) }

    context "when the data size is less than max_bytes" do
      let(:args) { base_args }
      let(:inventory) { small_json }

      before do
        allow(client).to receive(:save_inventory_with_http_info).with(small_json.to_json)
      end

      it "returns that it saved one chunk" do
        is_expected.to eq 1
      end

      it "does not split the payload into batches" do
        expect(client).to receive(:save_inventory_with_http_info).with(small_json.to_json).once
        subject
      end
    end

    context "when the data size is greater than specified max_bytes" do
      let(:args) { base_args.merge!(:max_bytes => 19_512) }
      let(:inventory) { big_json }

      before do
        allow(client).to receive(:save_inventory_with_http_info)
      end

      it "returns that it saved five chunks" do
        is_expected.to eq 5
      end

      it "splits the payload up into chunks" do
        expect(client).to receive(:save_inventory_with_http_info).exactly(5).times
        subject
      end
    end

    context "when the KAFKA_PAYLOAD_MAX_BYTES ENV var is set" do
      let(:args) { base_args }
      let(:inventory) { big_json }

      before do
        allow(ENV).to receive(:[]).with("KAFKA_PAYLOAD_MAX_BYTES").and_return("9_512")
        allow(client).to receive(:save_inventory_with_http_info)
      end

      it "splits the payload into smaller chunks" do
        expect(client).to receive(:save_inventory_with_http_info).exactly(10).times
        is_expected.to eq 10
      end
    end
  end
end
