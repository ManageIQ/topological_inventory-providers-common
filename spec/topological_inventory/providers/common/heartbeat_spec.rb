RSpec.describe TopologicalInventory::Providers::Common::Heartbeat do
  let(:heartbeat_file) { Pathname.new(File.expand_path("../../", __FILE__).to_s).join("tmp", "spec", "test.hb") }

  around do |spec|
    FileUtils.mkdir_p(heartbeat_file.parent)

    Timecop.travel(time) do
      File.write(heartbeat_file, "")
    end

    Timecop.freeze(time) { spec.run }

    FileUtils.rm_f(heartbeat_file.to_s)
  end

  let(:time) { Time.now.utc }

  before do
    stub_const("TopologicalInventory::Providers::Common::Heartbeat::HEARTBEAT_TIMEOUT", 2)
    stub_const("TopologicalInventory::Providers::Common::Heartbeat::HEARTBEAT_CHECK_TIMEOUT", 2)

    allow(described_class).to receive(:heartbeat_file_path).with("operations").and_return(heartbeat_file)
  end

  it "fails when heartbeat file is not created" do
    FileUtils.rm_f(heartbeat_file.to_s)

    Timecop.travel(time) do
      expect(described_class.check('operations')).to be_falsey
    end

    Timecop.travel(time) do
      File.write(heartbeat_file, "")
    end
  end

  it "performs heartbeat by calling method touch_heartbeat_file" do
    heartbeat = described_class.new('operations')

    Timecop.travel(time + 1) do
      expect(described_class.check('operations')).to be_truthy
    end

    Timecop.travel(time + 3) do
      expect(described_class.check('operations')).to be_falsey
    end

    Timecop.travel(time + 4) do
      heartbeat.touch_heartbeat_file
    end

    Timecop.travel(time + 5) do
      expect(described_class.check('operations')).to be_truthy
    end

    Timecop.travel(time + 6) do
      expect(described_class.check('operations')).to be_falsey
    end
  end

  it "performs heartbeat from thread" do
    stub_const("TopologicalInventory::Providers::Common::Heartbeat::HEARTBEAT_THREAD_TIMEOUT_STEP", 1)

    heartbeat = described_class.new('operations')
    heartbeat.heartbeat_queue.clear

    heartbeat.run_thread
    heartbeat.queue_tick

    sleep(TopologicalInventory::Providers::Common::Heartbeat::HEARTBEAT_THREAD_TIMEOUT_STEP + 1)
    expect(heartbeat.heartbeat_queue.count).to eq(0)

    Timecop.travel(time + 1) do # heartbeat didn't expired
      expect(described_class.check('operations')).to be_truthy
    end

    Timecop.travel(time + 3) do # heartbeat expired
      expect(described_class.check('operations')).to be_falsey
    end

    stub_const("TopologicalInventory::Providers::Common::Heartbeat::HEARTBEAT_THREAD_TIMEOUT_STEP", 0)
    heartbeat.stop
  end

  describe '#run_in_parallel_with' do
    it "performs heartbeat from touch_heartbeat_file with exceeding max limit" do
      stub_const("TopologicalInventory::Providers::Common::Heartbeat::HEARTBEAT_QUEUE_THREAD_TIMEOUT_STEP", 1)
      stub_const("TopologicalInventory::Providers::Common::Heartbeat::HEARTBEAT_TIMEOUT", 1)

      heartbeat = described_class.new('operations')
      heartbeat.heartbeat_queue.clear

      heartbeat.max_thread_timeout = 2

      Timecop.travel(time) do
        heartbeat.run_in_parallel_with do
          sleep(4)
        end
      end

      Timecop.travel(time + 1) do # heartbeat not expired
        expect(described_class.check('operations')).to be_truthy
      end

      Timecop.travel(time + 3) do # heartbeat expired as max_thread_timeout was exceed
        expect(described_class.check('operations')).to be_falsey
      end

      heartbeat.stop
    end
  end

  describe '#run_thread_queue_in_parallel_with' do
    it "performs heartbeat from thread with exceeding max limit" do
      stub_const("TopologicalInventory::Providers::Common::Heartbeat::HEARTBEAT_QUEUE_THREAD_TIMEOUT_STEP", 1)
      stub_const("TopologicalInventory::Providers::Common::Heartbeat::HEARTBEAT_TIMEOUT", 1)
      stub_const("TopologicalInventory::Providers::Common::Heartbeat::HEARTBEAT_CHECK_TIMEOUT", 2)

      heartbeat = described_class.new('operations')
      heartbeat.heartbeat_queue.clear
      heartbeat.run_thread
      heartbeat.max_thread_timeout = 2

      Timecop.travel(time) do
        heartbeat.run_thread_queue_in_parallel_with do
          sleep(4) # 4 seconds are exceeding HEARTBEAT_TIMEOUT(1 second) + HEARTBEAT_CHECK_TIMEOUT(2 seconds)
        end
      end

      Timecop.travel(time + 1) do # heartbeat not expired
        expect(described_class.check('operations')).to be_truthy
      end

      Timecop.travel(time + 4) do # heartbeat expired as max_thread_timeout was exceed
        expect(described_class.check('operations')).to be_falsey
      end

      heartbeat.stop
    end
  end
end
