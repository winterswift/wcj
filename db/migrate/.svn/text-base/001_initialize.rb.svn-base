#
# 20061115 jaa added group.description
# 
class Initialize < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.column :login, :string
      t.column :first_name, :string
      t.column :last_name, :string
      t.column :email, :string
      t.column :state, :string
      t.column :scope, :string
      t.column :introduction, :text
      t.column :avatar, :string
      t.column :crypted_password, :string, :limit => 40
      t.column :activation_code, :string, :limit => 40
      t.column :remember_token, :string, :limit => 40
      t.column :remember_token_expires_at, :datetime     
      t.column :activated_at, :datetime
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end
    
    create_table :groups do |t|
      t.column :user_id, :integer
      t.column :title, :string
      t.column :description, :string
      t.column :state, :string
      t.column :scope, :string
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
      t.column :created_by, :integer
      t.column :updated_by, :integer
    end
    
    create_table :roles do |t|
      t.column :title, :string
    end
    
    Role.create(:title => 'guest');
    Role.create(:title => 'user');
    Role.create(:title => 'admin');
    
    create_table :journals do |t|
      t.column :user_id, :integer
      t.column :title, :string
      t.column :introduction, :text
      t.column :state, :string
      t.column :scope, :string
      t.column :start_date, :date
      t.column :end_date, :date
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
      t.column :created_by, :integer
      t.column :updated_by, :integer
    end
    
    create_table :entries do |t|
      t.column :journal_id, :integer
      t.column :state, :string
      t.column :date, :date
      t.column :body, :text
      t.column :body_filtered, :text
      t.column :photo, :string
      
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
      t.column :created_by, :integer
      t.column :updated_by, :integer
    end
    
    create_table :comments do |t|
      t.column :user_id, :integer
      # 200701 replaced: t.column :title, :string
      t.column :title, :text
      t.column :comment, :string
      t.column :commentable_id, :integer
      t.column :commentable_type, :string
      
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
      t.column :created_by, :integer
      t.column :updated_by, :integer
    end
    
    create_table :urlnames do |t|
      t.column :nameable_type, :string
      t.column :nameable_id, :integer
      t.column :name, :string
    end
    
    # HABTM tables
    create_table :roles_users, :id => false do |t|
      t.column :role_id, :integer
      t.column :user_id, :integer
    end
    
    create_table :groups_users, :id => false do |t|
      t.column :group_id, :integer
      t.column :user_id, :integer
    end
    
    create_table :groups_journals, :id => false do |t|
      t.column :group_id, :integer
      t.column :journal_id, :integer
    end
  end

  def self.down
    drop_table :users
    drop_table :groups
    drop_table :roles
    drop_table :journals
    drop_table :entries
    drop_table :comments
    drop_table :urlnames
    
    drop_table :roles_users
    drop_table :groups_users
    drop_table :groups_journals
  end
end
