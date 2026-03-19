module Admin
  class TransactionsController < BaseController
    def index
      authorize Transaction
      @transactions = Transaction.includes(:customer, :user, :vehicle).order(created_at: :desc)
    end
  end
end
