class AddDigitalReceiptsAndExpenseLinesToSettlements < ActiveRecord::Migration[8.0]
  # Staff feedback items 10 and 12.
  #
  # 10 — digital receipts were two fixed columns (PhonePe POS and PhonePe
  # Scanner). Staff take PAYTM and other means too, so this becomes a
  # repeatable label + amount line. The two columns are backfilled into rows and
  # dropped; PhonePe POS and PhonePe Scanner survive as the two rows every draft
  # is seeded with, so the sheet still looks the way the FSM expects.
  #
  # 12 — a free-form expense line (salary advance or anything else taken out of
  # the day's cash), which reduces the amount the FSM has to hand over.
  DEFAULT_RECEIPT_LABELS = { "phonepe_pos_amount" => "PhonePe POS", "phonepe_scanner_amount" => "PhonePe Scanner" }.freeze

  def up
    create_table :settlement_digital_receipts do |t|
      t.references :daily_settlement, null: false, foreign_key: true
      t.string :label, null: false
      t.decimal :amount, precision: 12, scale: 2, default: 0, null: false
      t.timestamps
    end
    # One row per means; a second row for the same label is a duplicate, not a
    # second payment (the FSM totals a means before entering it).
    add_index :settlement_digital_receipts, %i[daily_settlement_id label], unique: true,
      name: "index_digital_receipts_on_settlement_key"

    create_table :settlement_expense_lines do |t|
      t.references :daily_settlement, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, default: 0, null: false
      t.timestamps
    end

    add_column :daily_settlements, :total_digital_receipt_amount, :decimal, precision: 12, scale: 2, default: 0, null: false
    add_column :daily_settlements, :total_expense_amount, :decimal, precision: 12, scale: 2, default: 0, null: false

    DEFAULT_RECEIPT_LABELS.each do |column, label|
      execute <<~SQL.squish
        INSERT INTO settlement_digital_receipts (daily_settlement_id, label, amount, created_at, updated_at)
        SELECT id, #{connection.quote(label)}, #{column}, NOW(), NOW()
        FROM daily_settlements WHERE #{column} > 0
      SQL
    end

    execute <<~SQL.squish
      UPDATE daily_settlements s
      SET total_digital_receipt_amount = COALESCE(r.total, 0)
      FROM daily_settlements base
      LEFT JOIN (SELECT daily_settlement_id, SUM(amount) AS total FROM settlement_digital_receipts GROUP BY 1) r
        ON r.daily_settlement_id = base.id
      WHERE s.id = base.id
    SQL

    remove_column :daily_settlements, :phonepe_pos_amount
    remove_column :daily_settlements, :phonepe_scanner_amount
  end

  def down
    add_column :daily_settlements, :phonepe_pos_amount, :decimal, precision: 12, scale: 2, default: 0, null: false
    add_column :daily_settlements, :phonepe_scanner_amount, :decimal, precision: 12, scale: 2, default: 0, null: false

    DEFAULT_RECEIPT_LABELS.each do |column, label|
      execute <<~SQL.squish
        UPDATE daily_settlements s SET #{column} = r.amount
        FROM settlement_digital_receipts r
        WHERE r.daily_settlement_id = s.id AND r.label = #{connection.quote(label)}
      SQL
    end

    remove_column :daily_settlements, :total_digital_receipt_amount
    remove_column :daily_settlements, :total_expense_amount
    drop_table :settlement_expense_lines
    drop_table :settlement_digital_receipts
  end
end
