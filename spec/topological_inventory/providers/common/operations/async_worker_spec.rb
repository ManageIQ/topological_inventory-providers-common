require "topological_inventory/providers/common/operations/async_worker"

describe TopologicalInventory::Providers::Common::Operations::AsyncWorker do
  let(:queue) { double }
  let(:impl) { double }
  let(:msg) { double }
  subject { described_class.new(impl, queue) }

  before do
    allow(queue).to receive(:length).and_return(0)
    allow(msg).to receive(:message).and_return("Source.availability_check")
  end

  context "when the message is able to be processed" do
    before do
      allow(impl).to receive(:process!).with(msg)
      allow(msg).to receive(:ack)
    end

    it "drains messages that are added to the queue" do
      expect(impl).to receive(:process!).with(msg).once
      subject.send(:process_message, msg)
    end
  end

  context "when the message results in an error" do
    before do
      allow(impl).to receive(:process!).with(msg).and_raise(StandardError.new("boom!"))
    end

    it "ack's the message on failure" do
      expect(msg).to receive(:ack).once
      subject.send(:process_message, msg)
    end
  end
end
