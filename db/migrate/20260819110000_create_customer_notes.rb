class CreateCustomerNotes < ActiveRecord::Migration[8.0]
  # Staff feedback item 13: "Notes that we add during customer capture should
  # have a timestamp. Every entry should be a new entry with timestamp, so we
  # know when and what we have spoken."
  #
  # `customers.info_note` was a single text column that each save overwrote, so
  # the previous conversation was lost every time. Notes become an append-only
  # log instead. The existing note is carried over as the first entry, stamped
  # with the customer's last update — the closest we can get to when it was
  # written — and the column is dropped.
  def up
    create_table :customer_notes do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :author, foreign_key: { to_table: :users } # null for backfilled notes
      t.text :body, null: false
      t.timestamps
    end
    add_index :customer_notes, %i[customer_id created_at]

    execute <<~SQL.squish
      INSERT INTO customer_notes (customer_id, body, created_at, updated_at)
      SELECT id, info_note, COALESCE(updated_at, created_at), COALESCE(updated_at, created_at)
      FROM customers
      WHERE info_note IS NOT NULL AND btrim(info_note) <> ''
    SQL

    remove_column :customers, :info_note
  end

  def down
    add_column :customers, :info_note, :text

    # Collapse the log back into one column, newest first.
    execute <<~SQL.squish
      UPDATE customers c SET info_note = n.combined
      FROM (
        SELECT customer_id, string_agg(body, E'\\n\\n' ORDER BY created_at DESC) AS combined
        FROM customer_notes GROUP BY customer_id
      ) n
      WHERE n.customer_id = c.id
    SQL

    drop_table :customer_notes
  end
end
