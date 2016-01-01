class CreateUploads < ActiveRecord::Migration
  def change
    create_table :uploads do |t|
      t.integer :live_id
      t.string :src
      t.string :dst
      t.integer :status

      t.timestamps null: false
    end
  end
end
