class CreateLivePrograms < ActiveRecord::Migration
  def change
    create_table :live_programs do |t|
      t.integer :live_id, null: false, unique: true
      t.datetime :started_at
      t.string :user
      t.text :title
      t.text :desc
      t.string :url
      t.text :player_status
      t.string :dl_status

      t.timestamps null: false
    end

    add_index :live_programs, :live_id
  end
end
