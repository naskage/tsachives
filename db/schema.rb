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

ActiveRecord::Schema.define(version: 20160101183837) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "jobs", force: :cascade do |t|
    t.integer  "live_id",                      null: false
    t.boolean  "divided",      default: false
    t.integer  "division_num"
    t.integer  "status"
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  add_index "jobs", ["live_id"], name: "index_jobs_on_live_id", using: :btree

  create_table "live_programs", force: :cascade do |t|
    t.integer  "live_id",       null: false
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

  add_index "live_programs", ["live_id"], name: "index_live_programs_on_live_id", using: :btree

  create_table "uploads", force: :cascade do |t|
    t.integer  "live_id"
    t.string   "src"
    t.string   "dst"
    t.integer  "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
