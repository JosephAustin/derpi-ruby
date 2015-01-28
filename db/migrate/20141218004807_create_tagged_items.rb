class CreateTaggedItems < ActiveRecord::Migration
  def change
    create_table :tagged_items do |t|
      t.integer :belongs_to
      t.string :derpId
      t.timestamps
    end
  end
end
