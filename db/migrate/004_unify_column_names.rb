class UnifyColumnNames < ActiveRecord::Migration
  def self.up
    rename_column(:users, :introduction, :description)
    rename_column(:journals, :introduction, :description)
  end

  def self.down
    rename_column(:users, :description, :introduction)
    rename_column(:journals, :description, :introduction)
  end
end
