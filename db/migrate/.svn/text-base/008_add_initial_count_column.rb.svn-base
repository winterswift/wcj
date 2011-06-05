class AddInitialCountColumn < ActiveRecord::Migration
  def self.up
    add_column(:journals, :initial_count, :integer, :default => 1)
  end

  def self.down
    remove_column(:journals, :initial_count)
  end
end
