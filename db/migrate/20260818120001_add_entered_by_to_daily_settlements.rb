class AddEnteredByToDailySettlements < ActiveRecord::Migration[8.1]
  # Admin-12 — `recorded_by` is the FSM the settlement BELONGS to; `entered_by` is
  # whoever actually typed it. They differ only when an admin enters a settlement
  # on behalf of an FSM who could not, which is the one case the admin is allowed
  # to enter anything at all.
  def change
    add_reference :daily_settlements, :entered_by, null: true,
      foreign_key: { to_table: :users, on_delete: :nullify }
  end
end
