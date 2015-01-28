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

ActiveRecord::Schema.define(version: 20150126211927) do

  create_table "local_copies", force: true do |t|
    t.string   "image_id"
    t.text     "link"
    t.text     "thumb"
    t.string   "score"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tagged_items", force: true do |t|
    t.integer  "belongs_to"
    t.integer  "image_id",   limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "user_keys", force: true do |t|
    t.string   "key"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "best_tags"
    t.text     "good_tags"
    t.text     "bad_tags"
    t.text     "worst_tags"
    t.text     "file_tags"
  end

end
