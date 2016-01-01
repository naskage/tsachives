# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160101113607) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "jobs", force: :cascade do |t|
    t.integer  "live_id",                       null: false
    t.text     "rtmp_url",                      null: false
    t.text     "player_ticket",                 null: false
    t.boolean  "divided",       default: false
    t.integer  "queue_no"
    t.text     "queue",                         null: false
    t.string   "file_name",                     null: false
    t.string   "options"
    t.integer  "status"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  create_table "live_programs", force: :cascade do |t|
    t.integer  "live_id"
    t.datetime "started_at"
    t.string   "user"
    t.text     "title"
    t.text     "desc"
    t.string   "url"
    t.text     "player_status"
    t.string   "dl_status"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

end
