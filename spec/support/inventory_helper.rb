module InventorySpecHelper
  def self.big_inventory(size, chunk_size)
    {
      :collections => [
        :name => SecureRandom.uuid,
        :data => data_chunks(size, chunk_size)
      ]
    }
  end

  def self.data_chunks(size, chunk)
    Array.new(size / chunk) { "a" * chunk }
  end
end
