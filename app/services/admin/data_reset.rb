module Admin
  # Admin-only destructive maintenance: wipe operational transaction data so the
  # site can restart from a clean slate (pilot data before go-live, or a bad
  # import). The admin picks *which* entities to drop, plus an optional date
  # range and/or a single customer, so the blast radius is always explicit.
  #
  # Web-only by design — deliberately not exposed on the API / native surface.
  class DataReset
    CONFIRMATION_PHRASE = "RESET".freeze

    Entity = Struct.new(:key, :label, :description, :model_name, :date_column, :date_only, :customer_column,
      keyword_init: true) do
      def model
        model_name.constantize
      end

      def customer_scoped?
        customer_column.present?
      end
    end

    ENTITIES = [
      Entity.new(
        key: "transactions",
        label: "Fuel transactions",
        description: "Every recorded sale (litres, ₹, discount, pump/nozzle). " \
                     "The points ledger entries attached to them are always removed with them.",
        model_name: "Transaction", date_column: :created_at, date_only: false, customer_column: :customer_id
      ),
      Entity.new(
        key: "points_ledgers",
        label: "Points ledger entries",
        description: "All loyalty point movement — earned, redeemed, expired and manual adjustments. " \
                     "Clearing this resets customer point balances to zero.",
        model_name: "PointsLedger", date_column: :created_at, date_only: false, customer_column: :customer_id
      ),
      Entity.new(
        key: "visit_entries",
        label: "Visit entries",
        description: "Fleet / OTP visit captures used by the cadence and churn reports.",
        model_name: "VisitEntry", date_column: :entry_date, date_only: true, customer_column: :customer_id
      ),
      Entity.new(
        key: "customer_feedbacks",
        label: "Customer feedback",
        description: "Ratings and comments captured against a transaction or a visit.",
        model_name: "CustomerFeedback", date_column: :created_at, date_only: false, customer_column: :customer_id
      ),
      Entity.new(
        key: "campaign_qualifications",
        label: "Campaign qualifications",
        description: "Per-customer campaign progress rows. These aggregate transaction totals, " \
                     "so they go stale once transactions are removed.",
        model_name: "CampaignQualification", date_column: :created_at, date_only: false, customer_column: :customer_id
      ),
      Entity.new(
        key: "daily_settlements",
        label: "Daily settlements",
        description: "Shift-end settlements and every child line (nozzle readings, cash denominations, " \
                     "credit / lube / discount lines, decantations, stock receipts, audit trail). " \
                     "Not customer-specific, so it is skipped when a customer is selected.",
        model_name: "DailySettlement", date_column: :business_date, date_only: true, customer_column: nil
      )
    ].freeze

    ENTITIES_BY_KEY = ENTITIES.index_by(&:key).freeze
    ENTITY_KEYS = ENTITIES.map(&:key).freeze

    # Children before parents: anything holding a FK to a row we are about to
    # remove is cleared (or DB-nullified) first.
    DELETION_ORDER = %w[
      customer_feedbacks campaign_qualifications points_ledgers
      transactions visit_entries daily_settlements
    ].freeze

    attr_reader :entity_keys, :start_date, :end_date, :customer

    def initialize(entity_keys: [], start_date: nil, end_date: nil, customer: nil)
      @entity_keys = Array(entity_keys).map(&:to_s) & ENTITY_KEYS
      @start_date, @end_date = normalized_dates(start_date, end_date)
      @customer = customer
    end

    def entities
      ENTITIES.select { |entity| selected?(entity.key) }
    end

    def selected?(key)
      entity_keys.include?(key.to_s)
    end

    # An entity is skipped when the admin narrowed to one customer but the table
    # has no customer of its own (settlements belong to a pump, not a customer).
    def applicable?(entity)
      customer.blank? || entity.customer_scoped?
    end

    def entities_selected?
      entities.any?
    end

    # Rows that would be removed right now, per entity key, for the current
    # filters — shown as the preview before anything is deleted.
    def counts
      ENTITIES.to_h { |entity| [entity.key, applicable?(entity) ? scope_for(entity).count : 0] }
    end

    # Points ledger rows hanging off the in-scope transactions. They must go
    # whenever transactions go (FK), even if the ledger box is left unchecked.
    def linked_points_ledger_count
      return 0 unless selected?("transactions")

      linked_points_ledgers.count
    end

    def scoped?
      start_date.present? || end_date.present? || customer.present?
    end

    # Deletes everything selected inside one transaction and returns the number
    # of rows removed per table.
    def call
      deleted = Hash.new(0)

      ApplicationRecord.transaction do
        DELETION_ORDER.each do |key|
          entity = ENTITIES_BY_KEY.fetch(key)
          next unless selected?(key) && applicable?(entity)

          # Clear the ledger rows the FK would otherwise block, then the parents.
          deleted["points_ledgers"] += linked_points_ledgers.delete_all if key == "transactions"
          deleted[key] += scope_for(entity).delete_all
        end

        reset_milestone_watermarks if deleted["points_ledgers"].positive?
      end

      deleted
    end

    def scope_for(entity)
      return entity.model.none unless applicable?(entity)

      scope = entity.model.all
      range = range_for(entity)
      scope = scope.where(entity.date_column => range) if range
      scope = scope.where(entity.customer_column => customer.id) if customer.present?
      scope
    end

    private

    def linked_points_ledgers
      PointsLedger.where(transaction_id: scope_for(ENTITIES_BY_KEY.fetch("transactions")).select(:id))
    end

    def range_for(entity)
      return nil if start_date.blank? && end_date.blank?

      if entity.date_only
        Range.new(start_date, end_date)
      else
        Range.new(start_date&.beginning_of_day, end_date&.end_of_day)
      end
    end

    # A wiped ledger has to re-arm the auto-milestone watermark, otherwise the
    # next earn would be measured against milestones that no longer exist.
    def reset_milestone_watermarks
      Customer.where.not(last_milestone_points: 0)
        .where.missing(:points_ledgers)
        .update_all(last_milestone_points: 0)
    end

    def normalized_dates(start_date, end_date)
      from = parse_date(start_date)
      to = parse_date(end_date)
      from.present? && to.present? && from > to ? [to, from] : [from, to]
    end

    def parse_date(value)
      return value if value.is_a?(Date)
      return nil if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
