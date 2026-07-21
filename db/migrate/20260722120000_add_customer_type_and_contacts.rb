class AddCustomerTypeAndContacts < ActiveRecord::Migration[8.1]
  def change
    # E4 — account type segmentation (OTP/Fleet, Drive-in, Credit) + fleet hints (B1).
    add_column :customers, :customer_type, :string, null: false, default: "drive_in"
    add_column :customers, :transport_name, :string
    add_column :customers, :approx_vehicle_count, :integer
    add_column :customers, :info_note, :text
    add_index :customers, :customer_type

    # B1 — driver/supervisor/owner/manager contacts with a "contacted-by" marker.
    create_table :customer_contacts do |t|
      t.references :customer, null: false, foreign_key: { on_delete: :cascade }
      t.string :role, null: false
      t.string :name
      t.string :phone_number
      t.boolean :contacted, null: false, default: false
      t.datetime :contacted_at
      t.text :notes
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :customer_contacts, [:customer_id, :role]
    add_index :customer_contacts, [:customer_id, :phone_number], unique: true,
      where: "phone_number IS NOT NULL", name: "index_customer_contacts_on_customer_and_phone"

    add_reference :customers, :primary_contact, null: true,
      foreign_key: { to_table: :customer_contacts, on_delete: :nullify }
  end
end
