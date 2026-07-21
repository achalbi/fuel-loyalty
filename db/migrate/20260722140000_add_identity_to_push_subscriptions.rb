class AddIdentityToPushSubscriptions < ActiveRecord::Migration[8.1]
  # Push tokens start anonymous. Optionally linking a subscription to the
  # registering staff `user` and/or an identified `customer` lets targeted
  # campaigns (F2) address a customer / customer-type instead of broadcasting.
  # Both are nullable and nullify on delete so an anonymous token still works.
  def change
    add_reference :push_subscriptions, :customer, null: true, foreign_key: { on_delete: :nullify }
    add_reference :push_subscriptions, :user, null: true, foreign_key: { on_delete: :nullify }
  end
end
