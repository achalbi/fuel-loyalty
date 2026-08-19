class AddOnBehalfOfToSettlementChanges < ActiveRecord::Migration[8.1]
  # D9 / Admin-12 — an admin should not be entering settlement data as himself.
  # When he does edit (because the FSM cannot), the audit row now records WHO the
  # edit was made for, alongside the admin who actually typed it (changed_by).
  def change
    add_reference :settlement_changes, :on_behalf_of, null: true,
      foreign_key: { to_table: :users, on_delete: :nullify }
  end
end
