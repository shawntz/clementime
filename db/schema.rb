# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_01_092920) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "constraints", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.string "constraint_type", null: false
    t.text "constraint_value"
    t.text "description"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id", "constraint_type"], name: "index_constraints_on_student_id_and_constraint_type"
    t.index ["student_id"], name: "index_constraints_on_student_id"
  end

  create_table "exam_slot_histories", force: :cascade do |t|
    t.bigint "exam_slot_id", null: false
    t.bigint "student_id", null: false
    t.bigint "section_id", null: false
    t.integer "exam_number"
    t.integer "week_number"
    t.date "date"
    t.string "start_time"
    t.string "end_time"
    t.boolean "is_scheduled"
    t.datetime "changed_at"
    t.string "changed_by"
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exam_slot_id"], name: "index_exam_slot_histories_on_exam_slot_id"
    t.index ["section_id"], name: "index_exam_slot_histories_on_section_id"
    t.index ["student_id"], name: "index_exam_slot_histories_on_student_id"
  end

  create_table "exam_slots", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "section_id", null: false
    t.integer "exam_number", null: false
    t.integer "week_number", null: false
    t.date "date"
    t.time "start_time"
    t.time "end_time"
    t.boolean "is_scheduled", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["section_id", "exam_number", "week_number"], name: "index_exam_slots_on_section_id_and_exam_number_and_week_number"
    t.index ["section_id"], name: "index_exam_slots_on_section_id"
    t.index ["student_id", "exam_number"], name: "index_exam_slots_on_student_id_and_exam_number", unique: true
    t.index ["student_id"], name: "index_exam_slots_on_student_id"
  end

  create_table "recordings", force: :cascade do |t|
    t.bigint "exam_slot_id", null: false
    t.bigint "section_id", null: false
    t.bigint "student_id", null: false
    t.bigint "ta_id", null: false
    t.string "recording_url"
    t.string "google_drive_file_id"
    t.datetime "recorded_at"
    t.datetime "uploaded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exam_slot_id"], name: "index_recordings_on_exam_slot_id", unique: true
    t.index ["section_id"], name: "index_recordings_on_section_id"
    t.index ["student_id"], name: "index_recordings_on_student_id"
    t.index ["ta_id"], name: "index_recordings_on_ta_id"
  end

  create_table "sections", force: :cascade do |t|
    t.string "code", null: false
    t.string "name"
    t.string "location"
    t.bigint "ta_id"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_sections_on_code", unique: true
    t.index ["ta_id"], name: "index_sections_on_ta_id"
  end

  create_table "students", force: :cascade do |t|
    t.string "canvas_id"
    t.string "sis_user_id", null: false
    t.string "sis_login_id"
    t.string "email", null: false
    t.string "full_name", null: false
    t.bigint "section_id", null: false
    t.string "week_group"
    t.string "slack_user_id"
    t.string "slack_username"
    t.boolean "slack_matched", default: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_students_on_email"
    t.index ["section_id"], name: "index_students_on_section_id"
    t.index ["sis_user_id"], name: "index_students_on_sis_user_id", unique: true
  end

  create_table "system_configs", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.string "config_type", default: "string"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_system_configs_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "ta", null: false
    t.boolean "is_active", default: true
    t.string "first_name"
    t.string "last_name"
    t.boolean "must_change_password", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "location"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "constraints", "students"
  add_foreign_key "exam_slot_histories", "exam_slots"
  add_foreign_key "exam_slot_histories", "sections"
  add_foreign_key "exam_slot_histories", "students"
  add_foreign_key "exam_slots", "sections"
  add_foreign_key "exam_slots", "students"
  add_foreign_key "recordings", "exam_slots"
  add_foreign_key "recordings", "sections"
  add_foreign_key "recordings", "students"
  add_foreign_key "recordings", "users", column: "ta_id"
  add_foreign_key "sections", "users", column: "ta_id"
  add_foreign_key "students", "sections"
end
