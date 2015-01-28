class AddFileTagSettings < ActiveRecord::Migration
  def change
    add_column :user_keys, :file_tags, :text
  end
end
