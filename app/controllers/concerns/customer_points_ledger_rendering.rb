module CustomerPointsLedgerRendering
  extend ActiveSupport::Concern

  POINTS_LEDGER_PREVIEW_LIMIT = 3
  POINTS_LEDGER_PER_PAGE = 5

  private

  def render_points_ledger_for(customer)
    total_remaining_entries = [customer.points_ledgers.count - POINTS_LEDGER_PREVIEW_LIMIT, 0].max
    total_pages = total_remaining_entries.zero? ? 1 : (total_remaining_entries.to_f / POINTS_LEDGER_PER_PAGE).ceil
    current_page = params[:page].to_i
    current_page = 1 if current_page < 1
    current_page = total_pages if current_page > total_pages

    points_ledger_entries = customer.points_ledgers
      .order(created_at: :desc)
      .offset(POINTS_LEDGER_PREVIEW_LIMIT + ((current_page - 1) * POINTS_LEDGER_PER_PAGE))
      .limit(POINTS_LEDGER_PER_PAGE)

    render partial: "customers/points_ledger",
      locals: {
        customer:,
        points_ledger_entries:,
        current_page:,
        total_pages:,
        total_remaining_entries:
      }
  end
end
