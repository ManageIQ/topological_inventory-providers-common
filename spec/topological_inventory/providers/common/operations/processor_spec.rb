RSpec.describe TopologicalInventory::Providers::Common::Operations::Processor do
  context "#process" do
    it "updates task with not_implemented error if operation not supported" do
      processor = described_class.new('SomeModel', 'some_method', { 'params' => { 'task_id' => '1' }}, {})
      expect(processor).to receive(:update_task).with('1',
                                                      :state => 'completed',
                                                      :status => 'error',
                                                      :context => { :error => "SomeModel#some_method Not Implemented"})
      processor.process
    end
  end
end
