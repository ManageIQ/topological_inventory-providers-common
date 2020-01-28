require "tempfile"
require "yaml"
require "json"

RSpec.describe TopologicalInventory::Providers::Common::CollectorsPool do
  let(:source1) { {:source => '42b1893c-ebbd-44e9-89b1-5c29b5fe6e10', :schema => 'http', :host => 'cloud.redhat.com', :port => 80} }
  let(:source2) { {:source => 'fe8bcaea-3670-42c7-bed9-71f6e0bceadd', :schema => 'https', :host => 'cloud.redhat.com', :port => 443} }
  let(:source3) { {:source => '05838743-4285-404a-b4d6-294045c0d4be', :schema => 'xxx', :host => 'cloud.redhat.com', :port => 1234} }
  let(:source4) { {:source => '5ed08a3c-3de4-4a90-8ce9-e0f724b2b2e6', :schema => 'xxx', :host => 'cloud.redhat.com', :port => 1234} }
  let(:sources) { [source1, source2, source3] }

  before do
    clear_settings
  end

  subject { described_class.new(nil, nil, :thread_pool_size => 2) }

  context "config reload" do
    it "changes settings with different configs" do
      settings = [{:sources => sources},
                  {:sources => [ source2, source4 ]}]

      2.times do |i|
        config = Tempfile.new(["config#{i}", '.yml'])
        begin
          config.write(settings[i].to_yaml)
          config.rewind

          name, path = path_and_filename(config)
          subject.send(:config_name=, name.split('.')[0])
          allow(subject).to receive(:path_to_config).and_return(path)

          subject.send(:reload_config)

          expect(::Settings.sources.to_a.collect(&:to_hash)).to eq(settings[i][:sources])
        ensure
          config.close
          config.unlink
        end
      end
    end
  end

  context "secret reload" do
    it "changes credentials with new secret" do
      uuid = SecureRandom.uuid

      secrets = [
        {'updated_at' => Time.now.to_s, uuid => {'username' => 'admin1', 'password' => 'password1'}},
        {'updated_at' => Time.now.to_s, uuid => {'username' => 'admin2', 'password' => 'password2'}},
      ]

      2.times do |i|
        secret = Tempfile.new(["credentials#{i}"])
        begin
          secret.write(secrets[i].to_json)
          secret.rewind

          name, path = path_and_filename(secret)

          allow(subject).to receive(:path_to_secrets).and_return(path)
          stub_const("#{described_class}::SECRET_FILENAME", name)

          subject.send(:reload_secrets)

          expect(subject.send(:secrets)).to eq(secrets[i])
        end
      end
    end
  end

  context "add or remove collector" do
    before do
      ::Config.load_and_set_settings('some-value-needed.txt')
      @collector = double("collector")
      allow(subject).to receive(:new_collector).and_return(@collector)
    end

    context "without secrets check" do
      before do
        allow(subject).to receive(:secrets_for_source).and_return({})
      end

      it "adds new collectors from settings" do
        allow(@collector).to receive(:collect!).and_return(nil)
        expect(@collector).to receive(:collect!).exactly(sources.size).times

        sources.each do |source|
          stub_settings_merge(:sources => ::Settings.sources.to_a + [source])

          subject.send(:queue_collectors)
        end

        pool = subject.send(:thread_pool)
        pool.shutdown
        pool.wait_for_termination
      end
    end

    context "with secrets check" do
      let(:secrets) do
        { 'updated_at' => Time.now.to_s,
          source1[:source] => { 'username' => 'admin1', 'password' => 'password1' },
          source2[:source] => { 'username' => 'admin2', 'password' => 'password2' },
          'unknown' => { 'username' => 'admin3', 'password' => 'password3' }
        }
      end

      before do
        allow(@collector).to receive(:collect!).and_return(nil)
      end

      it "creates only collectors found in both secret and config" do
        # 4 sources in yaml config
        stub_settings_merge(:sources => sources + [source4])
        # 3 sources in secret
        allow(subject).to receive(:secrets).and_return(secrets)

        # for each source in yaml secret is searched (4x)
        expect(subject).to receive(:secrets_for_source).and_call_original.exactly(4).times
        # only 2 corresponding
        expect(@collector).to receive(:collect!).exactly(2).times

        subject.send(:queue_collectors)

        pool = subject.send(:thread_pool)
        pool.shutdown
        pool.wait_for_termination
      end
    end
  end

  def stub_settings_merge(hash)
    if defined?(::Settings)
      Settings.add_source!(hash)
      Settings.reload!
    end
  end

  def clear_settings
    ::Settings.keys.dup.each { |k| ::Settings.delete_field(k) } if defined?(::Settings)
  end

  def path_and_filename(tempfile)
    parts = tempfile.path.split('/')
    name = parts[-1]
    path = parts[0..-2].join('/')
    [name, path]
  end
end
