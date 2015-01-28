class AddTagSettingsToIds < ActiveRecord::Migration
  def change
    add_column :user_keys, :best_tags, :text
    add_column :user_keys, :good_tags, :text
    add_column :user_keys, :bad_tags, :text
    add_column :user_keys, :worst_tags, :text
  end
end
