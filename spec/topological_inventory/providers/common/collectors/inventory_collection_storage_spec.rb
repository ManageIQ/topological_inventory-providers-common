describe TopologicalInventory::Providers::Common::Collector::InventoryCollectionStorage do
  before do
    @storage = described_class.new
  end

  it "should add collection to data" do
    @storage.add_collection(:vms)

    expect(@storage.data[:vms]).not_to be_nil
  end

  it "should access the same collection through brackets, method name and data" do
    @storage.add_collection(:vms)

    vm_name = "My VM"

    @storage[:vms].build(:name => vm_name)

    expect(@storage.vms.data[0].name).to eq(vm_name)
    expect(@storage[:vms].data[0].name).to eq(vm_name)
    expect(@storage.data[:vms].data[0].name).to eq(vm_name)
  end

  it "should create collection automatically when api object exists" do
    expect("TopologicalInventoryIngressApiClient::Vm".safe_constantize).not_to be_nil

    storage = described_class.new
    expect(storage.vms).to be_kind_of(TopologicalInventory::Providers::Common::Collector::InventoryCollectionWrapper)

    storage = described_class.new
    expect(storage[:vms]).to be_kind_of(TopologicalInventory::Providers::Common::Collector::InventoryCollectionWrapper)
  end

  it "should raise NameError when api object doesn't exist" do
    expect("TopologicalInventoryIngressApiClient::SomethingNonexisting".safe_constantize).to be_nil

    storage = described_class.new

    expect { storage.add_collection(:something_nonexisting) }.to raise_error(NameError)

    expect { storage.something_nonexisting.build(:name => "Vm") }.to raise_error(NameError)
  end

end
