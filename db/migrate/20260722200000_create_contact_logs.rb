class CreateContactLogs < ActiveRecord::Migration[8.1]
  # E5 — an outreach EVENT log. Distinct from `customer_contacts` (B1), which is a
  # roster of *people* (driver/supervisor/owner) with a single "have we reached
  # them" flag. A contact_log is one attempt to reach a customer: who logged it,
  # which person (optional), how (channel), and what happened (outcome). Multiple
  # logs accrete over time and feed the E5 contacted-count / last-contact / and the
  # conversion-probability heuristic.
  def change
    create_table :contact_logs do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      # The B1 contact person reached, when known; nullify on delete so a purged
      # contact does not erase the outreach history.
      t.references :customer_contact, null: true, foreign_key: { on_delete: :nullify }
      t.string :contacted_role
      t.string :channel, null: false
      t.string :outcome, null: false
      t.text :notes
      t.datetime :contacted_at, null: false
      t.timestamps
    end

    add_index :contact_logs, %i[customer_id contacted_at]
  end
end
