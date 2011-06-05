## generated 20061115
## script/generate migration add_feed_tools_tables
## based on feedtools-0.2.26

class AddFeedToolsTables < ActiveRecord::Migration
  def self.up
    puts "Adding cached feeds table..."
    create_table :cached_feeds do |t|
      t.column :href, :string
      t.column :title, :string
      t.column :link, :string
      t.column :feed_data, :text
      t.column :feed_data_type, :string
      t.column :http_headers, :text
      t.column :last_retrieved, :datetime
    end
  end

  def self.down
    puts "Dropping cached feeds table..."
    drop_table :cached_feeds
  end
end
