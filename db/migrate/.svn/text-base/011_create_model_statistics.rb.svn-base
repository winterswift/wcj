class CreateModelStatistics < ActiveRecord::Migration

  def self.up
    create_table :model_statistics do |t|
      t.column :instance_type, :string
      t.column :instance_id, :integer
      t.column :user_type, :string
      t.column :user_id, :integer
      t.column :request_uri, :string
      t.column :remote_addr, :string
      t.column :referer, :string
      t.column :session_id, :string
      t.column :created_at, :datetime
    end
    
    Settings.model_statistics_p = true;
  end
    
  def self.down
    drop_table :model_statistics
    
    Settings.model_statistics_p = false
    
  end

end
