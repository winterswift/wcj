

class CreateContactPermissions < ActiveRecord::Migration

  def self.up
    down() rescue nil
    add_column(:users, :contact_permissions, :string, :default => ['news'].to_yaml)
  end

  def self.down
    remove_column(:users, :contact_permissions)
  end

end

