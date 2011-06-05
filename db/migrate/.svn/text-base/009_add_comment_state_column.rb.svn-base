class AddCommentStateColumn < ActiveRecord::Migration
  def self.up
    add_column(:comments, :state, :string, :default => 'published')
    add_column(:journals, :comment_state, :string, :default => 'published')
  end

  def self.down
    remove_column(:comments, :state)
    remove_column(:journals, :comment_state)
  end
end
