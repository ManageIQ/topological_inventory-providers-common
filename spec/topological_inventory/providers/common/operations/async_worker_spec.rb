require "topological_inventory/providers/common/operations/async_worker"

describe TopologicalInventory::Providers::Common::Operations::AsyncWorker do
  let(:queue) { double }
  let(:impl) { double }
  let(:metrics) { double('metrics') }
  let(:msg) { double }
  let(:operation) { "Source.availability_check" }

  subject { described_class.new(impl, :queue => queue, :metrics => metrics) }

  before do
    allow(queue).to receive(:length).and_return(0)
    allow(msg).to receive(:message).and_return(operation)
  end

  context "when the message is able to be processed" do
    let(:result) { subject.operation_status[:success] }
    before do
      allow(impl).to receive(:process!).with(msg, metrics).and_return(result)
      allow(msg).to receive(:ack)
    end

    it "drains messages that are added to the queue" do
      expect(impl).to receive(:process!).with(msg, metrics).once
      expect(metrics).to receive(:record_operation).with(operation, :status => result)
      subject.send(:process_message, msg)
    end
  end

  context "when the message results in an error" do
    let(:result) { subject.operation_status[:error] }
    before do
      allow(impl).to receive(:process!).with(msg, metrics).and_raise(StandardError.new("boom!"))
    end

    it "ack's the message on failure" do
      allow(subject).to receive(:logger).and_return(double.as_null_object)
      
      expect(msg).to receive(:ack).once
      expect(metrics).to receive(:record_operation).with(operation, :status => result)
      subject.send(:process_message, msg)
    end
  end
end
