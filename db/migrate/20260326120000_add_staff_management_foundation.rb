class AddStaffManagementFoundation < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :active, :boolean, default: true, null: false
    add_column :users, :employee_code, :string
    add_index :users, :active
    add_index :users, :employee_code, unique: true

    create_table :shift_templates do |t|
      t.string :name, null: false
      t.integer :duration_minutes, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :shift_templates, :name, unique: true
    add_index :shift_templates, :active

    create_table :shift_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :shift_template, null: false, foreign_key: true
      t.date :effective_from, null: false
      t.date :effective_to
      t.boolean :active, default: true, null: false
      t.text :notes
      t.timestamps
    end

    add_index :shift_assignments, :active
    add_index :shift_assignments, [:user_id, :effective_from], name: "index_shift_assignments_on_user_and_effective_from"
    add_index :shift_assignments, [:shift_template_id, :effective_from], name: "index_shift_assignments_on_shift_and_effective_from"

    create_table :attendance_runs do |t|
      t.references :shift_template, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :shift_name_snapshot, null: false
      t.integer :duration_snapshot_minutes, null: false
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.text :notes
      t.timestamps
    end

    add_index :attendance_runs, [:shift_template_id, :starts_at], name: "index_attendance_runs_on_shift_and_starts_at"

    create_table :attendance_entries do |t|
      t.references :attendance_run, null: false, foreign_key: true
      t.references :scheduled_user, null: false, foreign_key: { to_table: :users }
      t.references :actual_user, foreign_key: { to_table: :users }
      t.references :replacement_user, foreign_key: { to_table: :users }
      t.string :external_replacement_name
      t.integer :status, default: 0, null: false
      t.datetime :check_in_at
      t.datetime :check_out_at
      t.text :notes
      t.boolean :overridden, default: false, null: false
      t.datetime :last_overridden_at
      t.references :last_overridden_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :attendance_entries, :status
    add_index :attendance_entries, [:attendance_run_id, :scheduled_user_id], unique: true, name: "index_attendance_entries_on_run_and_scheduled_user"

    create_table :shift_swaps do |t|
      t.references :from_user, null: false, foreign_key: { to_table: :users }
      t.references :to_user, null: false, foreign_key: { to_table: :users }
      t.references :from_shift_template, null: false, foreign_key: { to_table: :shift_templates }
      t.references :to_shift_template, foreign_key: { to_table: :shift_templates }
      t.integer :swap_kind, default: 0, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.text :reason, null: false
      t.timestamps
    end

    add_index :shift_swaps, [:from_user_id, :starts_at], name: "index_shift_swaps_on_from_user_and_starts_at"
    add_index :shift_swaps, [:to_user_id, :starts_at], name: "index_shift_swaps_on_to_user_and_starts_at"

    create_table :attendance_entry_changes do |t|
      t.references :attendance_entry, null: false, foreign_key: true
      t.references :changed_by, null: false, foreign_key: { to_table: :users }
      t.string :change_reason, null: false
      t.jsonb :before_payload, null: false, default: {}
      t.jsonb :after_payload, null: false, default: {}
      t.timestamps
    end
  end
end
