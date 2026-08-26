class AddPriorClosingToSettlementNozzleReadings < ActiveRecord::Migration[8.1]
  # Business rule 1 auto-pops the opening reading from the previous settlement's
  # closing, and the FSM may now correct it: a pump that went a few days
  # unsettled kept selling, so the last recorded closing is behind the meter and
  # is not today's opening. Snapshot the figure that was offered — and the date
  # it came from, which is how a gap becomes visible instead of implied — so the
  # sheet can show what the operator changed and from when.
  def up
    add_column :settlement_nozzle_readings, :prior_closing_reading, :decimal, precision: 12, scale: 3
    add_column :settlement_nozzle_readings, :prior_closing_date, :date

    # Rows already marked `prior_settlement` took their opening straight from the
    # prior closing, so that opening *is* the figure that was offered. The date
    # it came from is not recoverable cheaply and stays null; the hint degrades
    # to the figure alone.
    execute <<~SQL.squish
      UPDATE settlement_nozzle_readings
         SET prior_closing_reading = opening_reading
       WHERE opening_source = 'prior_settlement'
    SQL
  end

  def down
    remove_column :settlement_nozzle_readings, :prior_closing_date
    remove_column :settlement_nozzle_readings, :prior_closing_reading
  end
end
