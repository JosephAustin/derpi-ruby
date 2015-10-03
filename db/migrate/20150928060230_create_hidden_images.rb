class CreateHiddenImages < ActiveRecord::Migration
  def change
    create_table :hidden_images do |t|
      t.integer :image_id
      t.integer :user_id
    end
  end
end
