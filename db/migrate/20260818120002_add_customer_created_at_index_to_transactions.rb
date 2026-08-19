class AddCustomerCreatedAtIndexToTransactions < ActiveRecord::Migration[8.1]
  # The admin customers list rolls transactions up per customer over a date
  # window (Admin::Crm::CustomerMetrics). `transactions` had an index on
  # customer_id alone, so every period-scoped rollup re-read the whole customer's
  # history; the composite lets Postgres range-scan straight to the window.
  def change
    add_index :transactions, %i[customer_id created_at]
  end
end
