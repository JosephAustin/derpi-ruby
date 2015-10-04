class CreateHiddenIndexers < ActiveRecord::Migration
  def change
    create_table :hidden_indexers do |t|
		t.integer :user_id
		t.string :indexer
    end
  end
end
