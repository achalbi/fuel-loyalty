module Admin
  class DashboardController < BaseController
    def show
      authorize :dashboard, :show?
      @customers_count = Customer.count
      @transactions_count = Transaction.count
      @points_issued = PointsLedger.sum(:points)
    end
  end
end
