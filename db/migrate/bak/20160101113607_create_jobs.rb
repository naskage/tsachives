class CreateJobs < ActiveRecord::Migration
  def change
    create_table :jobs do |t|
      t.integer :live_id, null: false, unique: true
      # t.text :rtmp_url, null: false
      # t.text :player_ticket, null: false
      t.boolean :divided, default: false
      t.integer :division_num
      # t.integer :queue_no
      # t.text :queue, null: false
      # t.string :file_name, null: false
      # t.string :options
      t.integer :status

      t.timestamps null: false
    end

    add_index :jobs, :live_id
  end
end
