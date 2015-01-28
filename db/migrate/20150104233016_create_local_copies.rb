class CreateLocalCopies < ActiveRecord::Migration
  def change
    create_table :local_copies do |t|
      t.string :image_id
      t.text :link
      t.text :thumb
      t.string :score

      t.timestamps
    end
  end
end
