class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :key
      t.text :best_tags
      t.text :bad_tags
      t.text :good_tags
      t.text :worst_tags
      t.text :file_tags
    end
  end
end
