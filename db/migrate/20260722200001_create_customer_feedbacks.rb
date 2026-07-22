class CreateCustomerFeedbacks < ActiveRecord::Migration[8.1]
  # E7 — customer feedback / rating (1..5 + optional comment). Optionally tied to
  # the visit or the loyalty transaction it rates. `source` records who supplied
  # it (staff at the pump, admin, or a future SMS reply). Feedback is immutable
  # audit data; there is one feedback per transaction/visit at most.
  def change
    create_table :customer_feedbacks do |t|
      t.references :customer, null: false, foreign_key: true
      # class Transaction — fk column is transaction_id; the association is named
      # :fuel_transaction on the model to avoid shadowing ActiveRecord#transaction.
      # index: false — the unique partial indexes below cover these columns.
      t.references :transaction, null: true, index: false, foreign_key: { on_delete: :nullify }
      t.references :visit_entry, null: true, index: false, foreign_key: { on_delete: :nullify }
      t.references :recorded_by_user, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :rating, null: false
      t.text :comment
      t.string :source, null: false, default: "staff"
      t.timestamps
    end

    add_index :customer_feedbacks, :transaction_id, unique: true,
              where: "transaction_id IS NOT NULL", name: "index_customer_feedbacks_on_transaction_id_unique"
    add_index :customer_feedbacks, :visit_entry_id, unique: true,
              where: "visit_entry_id IS NOT NULL", name: "index_customer_feedbacks_on_visit_entry_id_unique"
  end
end
