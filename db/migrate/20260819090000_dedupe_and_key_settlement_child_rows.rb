class DedupeAndKeySettlementChildRows < ActiveRecord::Migration[8.0]
  # Staff feedback (item 6): "daily settlement is multiplying if submitted
  # twice". The Android form kept null ids on its child rows after the first
  # save, so a second submit posted them as new nested records — a whole extra
  # set of readings, lubes, denominations, stock and rate rows, doubling the
  # settlement's totals. The client is fixed to re-read the saved ids; this
  # migration repairs the rows already written and makes the duplicate
  # impossible at the database level.
  #
  # Each of these children is keyed — one row per nozzle, per lube product, per
  # denomination, per fuel type, per competitor — so a second row for the same
  # key is always a duplicate. The newest row wins: if the FSM changed a figure
  # before re-submitting, that is the figure they meant. Credit and discount
  # lines are deliberately left alone; they have no natural key, so a second row
  # there may be a genuine second credit.
  KEYED_CHILDREN = {
    "settlement_nozzle_readings" => %w[fuel_pump_nozzle_id],
    "settlement_lube_lines" => %w[product_id],
    "settlement_cash_denominations" => %w[denomination],
    "settlement_stock_receipts" => %w[fuel_type_code],
    "settlement_rate_comparisons" => %w[fuel_type_code competitor_name]
  }.freeze

  def up
    KEYED_CHILDREN.each do |table, key_columns|
      # IS NOT DISTINCT FROM so two rows that are both NULL on a nullable key
      # column still count as the same key.
      key_match = key_columns.map { |column| "t.#{column} IS NOT DISTINCT FROM newer.#{column}" }.join(" AND ")

      execute <<~SQL.squish
        DELETE FROM #{table} t
        USING #{table} newer
        WHERE t.daily_settlement_id = newer.daily_settlement_id
          AND #{key_match}
          AND t.id < newer.id
      SQL

      add_index table, [ "daily_settlement_id", *key_columns ],
        unique: true, nulls_not_distinct: true, name: index_name_for(table)
    end

    recompute_settlement_totals!
  end

  def down
    KEYED_CHILDREN.each_key { |table| remove_index table, name: index_name_for(table) }
  end

  private

  def index_name_for(table)
    "index_#{table.delete_prefix('settlement_')}_on_settlement_key"
  end

  # Stored aggregates were computed from the duplicated rows, so re-derive them
  # from what survives. Mirrors Settlement::Calculator (D6/D7) exactly.
  def recompute_settlement_totals!
    execute <<~SQL.squish
      UPDATE daily_settlements s SET
        total_fuel_amount = COALESCE(f.total, 0),
        total_lube_amount = COALESCE(l.total, 0),
        total_discount_amount = COALESCE(d.total, 0),
        total_credit_amount = COALESCE(c.total, 0),
        counted_cash_amount = COALESCE(k.total, 0),
        final_amount_to_settle = ROUND(
          (COALESCE(f.total, 0) + COALESCE(l.total, 0))
          - (COALESCE(d.total, 0) + COALESCE(c.total, 0) + s.phonepe_pos_amount + s.phonepe_scanner_amount), 2),
        shortage_amount = ROUND(
          (COALESCE(f.total, 0) + COALESCE(l.total, 0))
          - (COALESCE(d.total, 0) + COALESCE(c.total, 0) + s.phonepe_pos_amount + s.phonepe_scanner_amount)
          - COALESCE(k.total, 0), 2)
      FROM daily_settlements base
      LEFT JOIN (SELECT daily_settlement_id, SUM(amount) AS total FROM settlement_nozzle_readings GROUP BY 1) f
        ON f.daily_settlement_id = base.id
      LEFT JOIN (SELECT daily_settlement_id, SUM(amount) AS total FROM settlement_lube_lines GROUP BY 1) l
        ON l.daily_settlement_id = base.id
      LEFT JOIN (SELECT daily_settlement_id, SUM(discount_amount) AS total FROM settlement_discount_lines GROUP BY 1) d
        ON d.daily_settlement_id = base.id
      LEFT JOIN (SELECT daily_settlement_id, SUM(amount) AS total FROM settlement_credit_lines GROUP BY 1) c
        ON c.daily_settlement_id = base.id
      LEFT JOIN (SELECT daily_settlement_id, SUM(amount) AS total FROM settlement_cash_denominations GROUP BY 1) k
        ON k.daily_settlement_id = base.id
      WHERE s.id = base.id
    SQL
  end
end
