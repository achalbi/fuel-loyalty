module CustomerTransactionHistoryRendering
  extend ActiveSupport::Concern

  TRANSACTION_PREVIEW_LIMIT = 3
  TRANSACTION_HISTORY_PER_PAGE = 5

  private

  def render_transaction_history_for(customer)
    total_remaining_entries = [customer.transactions.count - TRANSACTION_PREVIEW_LIMIT, 0].max
    total_pages = total_remaining_entries.zero? ? 1 : (total_remaining_entries.to_f / TRANSACTION_HISTORY_PER_PAGE).ceil
    current_page = params[:page].to_i
    current_page = 1 if current_page < 1
    current_page = total_pages if current_page > total_pages

    transaction_history_entries = customer.transactions
      .includes(:vehicle, :user)
      .order(created_at: :desc)
      .offset(TRANSACTION_PREVIEW_LIMIT + ((current_page - 1) * TRANSACTION_HISTORY_PER_PAGE))
      .limit(TRANSACTION_HISTORY_PER_PAGE)

    render partial: "customers/transaction_history",
      locals: {
        customer:,
        transaction_history_entries:,
        current_page:,
        total_pages:,
        total_remaining_entries:
      }
  end
end
