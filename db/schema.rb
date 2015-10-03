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

ActiveRecord::Schema.define(version: 20150928060230) do

  create_table "hidden_images", force: :cascade do |t|
    t.integer "image_id"
    t.integer "user_id"
  end

  create_table "images", force: :cascade do |t|
    t.string  "indexer"
    t.string  "thumb_link"
    t.string  "tags"
    t.string  "score"
    t.boolean "dead"
    t.string  "base_link"
    t.string  "extension"
  end

  create_table "users", force: :cascade do |t|
    t.string "key"
    t.text   "best_tags"
    t.text   "bad_tags"
    t.text   "good_tags"
    t.text   "worst_tags"
    t.text   "file_tags"
  end

end
