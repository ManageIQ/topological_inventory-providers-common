describe TopologicalInventory::Providers::Common::Collector::InventoryCollectionWrapper do
  it "builds only existing ingress api client's object" do
    ic = described_class.new(:name => :some_undefined_class_in_api_models)
    ic_existing = described_class.new(:name => :vm)

    expect { ic.build({}) }.to raise_error(NameError)
    expect(ic_existing.build({})).to be_kind_of(TopologicalInventoryIngressApiClient::Vm)
  end
end
