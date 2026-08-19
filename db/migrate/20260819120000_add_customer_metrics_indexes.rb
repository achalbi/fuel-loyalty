class AddCustomerMetricsIndexes < ActiveRecord::Migration[8.0]
  # Staff feedback item 4: the admin customer list now runs a per-row correlated
  # subquery for each of visits, litres, discount, contacts and points. Every one
  # of them looks up "this customer's rows, optionally inside a date window", so
  # each needs a [customer_id, <time column>] index or the list degrades into a
  # sequential scan per page.
  #
  # contact_logs already has index_contact_logs_on_customer_id_and_contacted_at
  # (20260722200000_create_contact_logs), so it is deliberately absent here.
  #
  # The plain single-column customer_id indexes stay: they still serve the
  # has_many loads and the foreign keys.
  def change
    add_index :transactions, %i[customer_id created_at]
    add_index :points_ledgers, %i[customer_id created_at]
    add_index :visit_entries, %i[customer_id entry_date]
  end
end
