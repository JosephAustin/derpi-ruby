class CreateImages < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.string :indexer
      t.string :thumb_link
      t.string :tags
      t.string :score
      t.boolean :dead
      t.string :base_link
      t.string :extension
    end
  end
end
