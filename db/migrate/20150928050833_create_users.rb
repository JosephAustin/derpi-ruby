class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :key
      t.text :best_tags, :text
      t.text :bad_tags, :text
      t.text :good_tags, :text
      t.text :worst_tags, :text
      t.text :file_tags, :text
    end
  end
end
