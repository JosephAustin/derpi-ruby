class FixColumnName < ActiveRecord::Migration
  def change
    rename_column :tagged_items, :derpId, :image_id
  end
end
