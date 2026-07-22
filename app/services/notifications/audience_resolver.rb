module Notifications
  # Resolves a target descriptor into the candidate customer set. `all` is a
  # special marker: for push it means every active token (including anonymous
  # ones); for WhatsApp/SMS it means every opted-in customer. The Dispatcher
  # applies the per-channel opt-in / token gating on top of this.
  class AudienceResolver
    Result = Struct.new(:all, :customers, keyword_init: true) do
      def all? = all
    end

    def self.call(...) = new(...).call

    def initialize(target_type:, target_customer_type: nil, customer_ids: nil)
      @target_type = target_type.to_s
      @target_customer_type = target_customer_type.to_s.strip.presence
      @customer_ids = Array(customer_ids).compact_blank
    end

    def call
      case @target_type
      when "all"
        Result.new(all: true, customers: Customer.active)
      when "customer_type"
        Result.new(all: false, customers: Customer.active.where(customer_type: normalized_type))
      when "individual", "selected"
        Result.new(all: false, customers: Customer.active.where(id: @customer_ids))
      else
        Result.new(all: false, customers: Customer.none)
      end
    end

    private

    def normalized_type
      Customer.customer_types.key?(@target_customer_type) ? @target_customer_type : "__none__"
    end
  end
end
