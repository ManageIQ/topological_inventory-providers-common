RSpec.describe TopologicalInventory::Providers::Common::Logger do
  let(:status) { :test }
  let(:source) { '92844e11-17d5-4998-a33d-d886c3c7a80e' }
  let(:entity_type) { 'test-entity' }
  let(:refresh_state_uuid) { 'cd22ba1c-56f6-4fd4-a191-ec8eb8e993a8' }
  let(:sweep_scope) { [entity_type] }
  let(:total_parts) { 10 }

  subject { described_class.new }

  it 'receives collecting method' do
    msg = "[#{status.to_s.upcase}] Collecting #{entity_type}"
    msg += ", :total parts => #{total_parts}" if total_parts.present?
    msg += ", :source_uid => #{source}, :refresh_state_uuid => #{refresh_state_uuid}"
    expect(subject).to receive(:info).with(msg)

    subject.collecting(status, source, entity_type, refresh_state_uuid, total_parts)
  end

  it 'receives sweeping method' do
    msg = "[#{status.to_s.upcase}] Sweeping inactive records, :sweep_scope => #{sweep_scope}, :source_uid => #{source}, :refresh_state_uuid => #{refresh_state_uuid}"
    expect(subject).to receive(:info).with(msg)

    subject.sweeping(status, source, sweep_scope, refresh_state_uuid)
  end

  it 'receives collecting error method' do
    begin
      raise 'Test exception'
    rescue => e
      msg = "[ERROR] Collecting #{entity_type}, :source_uid => #{source}, :refresh_state_uuid => #{refresh_state_uuid}"
      msg += ":message => #{e.message}\n#{e.backtrace.join("\n")}"
      expect(subject).to receive(:error).with(msg)

      subject.collecting_error(source, entity_type, refresh_state_uuid, e)
    end
  end
end
