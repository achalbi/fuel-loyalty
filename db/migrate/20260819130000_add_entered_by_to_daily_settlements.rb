class AddEnteredByToDailySettlements < ActiveRecord::Migration[8.0]
  # Staff feedback item 3 (final part): an admin may record a settlement ON
  # BEHALF OF a named FSM who could not do it themselves (absent, sick, dead
  # device).
  #
  # Attribution does not move: the sheet stays the FSM's, so `recorded_by_id`
  # keeps pointing at them and `fsm_name_snapshot` keeps their name. This column
  # records the OTHER half of the story — the admin who actually typed it — so
  # "recorded for Suresh, entered by Admin" is a fact on the row rather than
  # something to reconstruct from the audit trail.
  #
  # Nullable, and NULL is the normal case: a sheet an FSM recorded themselves
  # has no separate enterer. That also keeps every settlement already on the
  # books valid without a backfill — including the ones an admin captured
  # through the old (now closed) `/staff/settlements/new` back door, which are
  # indistinguishable from FSM-recorded sheets and must stay that way rather
  # than be retro-labelled with a guess.
  def change
    add_reference :daily_settlements, :entered_by,
      null: true, index: true, foreign_key: { to_table: :users }
  end
end
