require "test_helper"

class RewardSettingTest < ActiveSupport::TestCase
  test "current defaults rewards_paused to false" do
    assert_equal false, RewardSetting.current.rewards_paused?
  end

  test "rewards_paused can be toggled on and off" do
    RewardSetting.current.update!(rewards_paused: true)
    assert RewardSetting.current.rewards_paused?

    RewardSetting.current.update!(rewards_paused: false)
    assert_not RewardSetting.current.rewards_paused?
  end

  test "rejects a nil rewards_paused" do
    setting = RewardSetting.current
    setting.rewards_paused = nil
    assert setting.valid?, "before_validation should backfill rewards_paused to false"
    assert_equal false, setting.rewards_paused
  end
end
