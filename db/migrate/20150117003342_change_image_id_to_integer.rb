class ChangeImageIdToInteger < ActiveRecord::Migration
  def change
    change_column :tagged_items, :image_id, :integer
  end
end
