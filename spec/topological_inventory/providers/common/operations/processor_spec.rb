require "topological_inventory/providers/common/operations/processor"

RSpec.describe TopologicalInventory::Providers::Common::Operations::Processor do
  let(:operation_name) { 'Source.availability_check' }
  let(:params) { {'source_id' => 1, 'external_tenant' => '12345'} }
  let(:payload) { {"params" => params, "request_context" => double('request_context')} }
  let(:message) { double("ManageIQ::Messaging::ReceivedMessage", :message => operation_name, :payload => payload) }

  subject { described_class.new(message, nil) }

  describe "#process" do
    it "starts the operation if class and method exists" do
      result = double('result')

      klass = TopologicalInventory::Providers::Common::Operations::Source
      allow(subject).to receive(:operation_class).and_return(klass)

      source = klass.new(params, payload['request_context'], nil)
      expect(klass).to receive(:new).with(params, payload['request_context'], nil).and_return(source)
      expect(source).to receive(:availability_check).and_return(result)

      expect(subject.process).to eq(result)
    end

    it "returns 'not_implemented' if class of method doesn't exist" do
      allow(subject).to receive(:operation_class).and_return(nil)
      allow(subject).to receive(:method).and_return('awesome')

      expect(subject.process).to eq(subject.operation_status[:not_implemented])
    end

    it "updates task if not_implemented" do
      allow(subject).to receive(:operation_class).and_return(nil)
      allow(subject).to receive(:method).and_return('awesome')

      subject.send(:params)['task_id'] = '1'
      expect(subject).to(receive(:update_task).with('1',
                                                    :state   => "completed",
                                                    :status  => "error",
                                                    :context => anything))
      subject.process
    end

    it "updates task if exception raised" do
      subject.send(:params)['task_id'] = '1'
      expect(subject).to(receive(:update_task).with('1',
                                                    :state   => "completed",
                                                    :status  => "error",
                                                    :context => anything))
      expect { subject.process }.to raise_exception(NotImplementedError)
    end
  end

  describe "#with_time_measure" do
    let(:metrics) { double("Metrics") }

    it "records time and yields if metrics provided" do
      allow(subject).to receive(:metrics).and_return(metrics)

      expect(metrics).to receive(:record_operation_time).with(operation_name).and_yield

      expect(subject.send(:with_time_measure) { 42 }).to eq(42)
    end

    it "only yields if metrics not present" do
      expect(metrics).not_to receive(:record_operation_time)

      expect(subject.send(:with_time_measure) { 42 }).to eq(42)
    end
  end
end
