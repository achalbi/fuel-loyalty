class RemapSettlementCreditLineTypes < ActiveRecord::Migration[8.0]
  # Staff feedback (item 9): a credit line's type should be the customer type —
  # Drive-In / Credit / Fleet-OTP — not the old Fleet-OTP / Tank-truck pair.
  # `fleet_otp` keeps its value (0) so installed app builds keep working; the
  # retired `tank_truck` (1) becomes `credit` (3), which is what a tank-truck
  # credit sale was being used to record.
  TANK_TRUCK = 1
  CREDIT = 3

  def up
    execute <<~SQL.squish
      UPDATE settlement_credit_lines SET credit_type = #{CREDIT} WHERE credit_type = #{TANK_TRUCK}
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE settlement_credit_lines SET credit_type = #{TANK_TRUCK} WHERE credit_type = #{CREDIT}
    SQL
  end
end
