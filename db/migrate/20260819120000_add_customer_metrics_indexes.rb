class AddCustomerMetricsIndexes < ActiveRecord::Migration[8.1]
  # Admin cohort filters run a per-row correlated subquery for visits, litres,
  # discount, contacts and points. Each looks up "this customer's rows, optionally
  # inside a date window", so each needs a [customer_id, <time column>] index or
  # the list degrades into a sequential scan per page.
  #
  # transactions already has index_transactions_on_customer_id_and_created_at
  # (20260818120002) and contact_logs already has its own
  # index_contact_logs_on_customer_id_and_contacted_at (20260722200000), so both
  # are deliberately absent here.
  def change
    add_index :points_ledgers, %i[customer_id created_at]
    add_index :visit_entries, %i[customer_id entry_date]
  end
end
