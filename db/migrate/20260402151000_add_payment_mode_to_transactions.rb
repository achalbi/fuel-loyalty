class AddPaymentModeToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :payment_mode, :string, null: false, default: "cash"
  end
end
