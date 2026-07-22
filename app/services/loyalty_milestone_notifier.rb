class LoyaltyMilestoneNotifier
  # F3 — when a customer's running loyalty total crosses a new multiple of the
  # configured step (RewardSetting#milestone_step), send exactly one
  # "you've earned N points" notification over the channels they can be reached
  # on, and advance customers.last_milestone_points so it never double-fires.
  # Idempotent; any delivery failure is swallowed so it can't affect the
  # transaction that triggered it.
  def self.call(...) = new(...).call

  def initialize(customer)
    @customer = customer
  end

  def call
    step = RewardSetting.current.milestone_step.to_i
    return if step <= 0

    rung = (@customer.total_points.to_i / step) * step
    return if rung <= 0 || rung <= @customer.last_milestone_points.to_i

    channels = @customer.reachable_channels
    if channels.any?
      Notifications::Broadcaster.call(
        title: "You've earned #{rung} points!",
        body: "Thanks for fuelling with us — you're now at #{@customer.total_points} loyalty points. Keep them coming!",
        category: :loyalty_milestone,
        target_type: "individual",
        customer_ids: [@customer.id],
        channels: channels
      )
    end

    @customer.update_column(:last_milestone_points, rung)
  rescue StandardError => error
    Rails.logger.warn("[LoyaltyMilestoneNotifier] #{error.class}: #{error.message}")
    nil
  end
end
