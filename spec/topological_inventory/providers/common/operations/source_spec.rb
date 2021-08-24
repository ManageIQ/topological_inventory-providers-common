require "topological_inventory/providers/common/operations/source"

RSpec.describe TopologicalInventory::Providers::Common::Operations::Source do
  context "PSK" do
    around do |example|
      ENV['SOURCES_PSK'] = '1234'
      example.run
      ENV['SOURCES_PSK'] = nil
    end

    it_behaves_like "availability_check"
  end

  it_behaves_like "availability_check"
end
