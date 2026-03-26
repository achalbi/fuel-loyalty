require "test_helper"

class ShiftCycleTest < ActiveSupport::TestCase
  test "window_for keeps repeating through the cycle" do
    shift_cycle = shift_cycles(:day_night_cycle)

    travel_to Time.zone.parse("2026-03-26 06:00") do
      window = shift_cycle.window_for(Time.zone.parse("2026-03-26 06:00"))

      assert_equal shift_templates(:day_shift), window[:shift_template]
      assert_equal Time.zone.parse("2026-03-26 06:00"), window[:starts_at]
      assert_equal Time.zone.parse("2026-03-26 18:00"), window[:ends_at]
    end

    travel_to Time.zone.parse("2026-03-26 18:00") do
      window = shift_cycle.window_for(Time.zone.parse("2026-03-26 18:00"))

      assert_equal shift_templates(:night_shift), window[:shift_template]
      assert_equal Time.zone.parse("2026-03-26 18:00"), window[:starts_at]
      assert_equal Time.zone.parse("2026-03-27 18:00"), window[:ends_at]
    end
  end

  test "valid_window_for requires the exact repeating window boundaries" do
    shift_cycle = shift_cycles(:day_night_cycle)

    assert shift_cycle.valid_window_for?(
      shift_template: shift_templates(:day_shift),
      starts_at: Time.zone.parse("2026-03-26 06:00"),
      ends_at: Time.zone.parse("2026-03-26 18:00")
    )

    assert_not shift_cycle.valid_window_for?(
      shift_template: shift_templates(:day_shift),
      starts_at: Time.zone.parse("2026-03-26 08:00"),
      ends_at: Time.zone.parse("2026-03-26 20:00")
    )
  end
end
