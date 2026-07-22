module Admin
  # E6 — the lost-customer / reach-out list: customers who visited the previous
  # comparable period but not the current one, ranked by conversion probability.
  class ReachOutController < BaseController
    def index
      authorize :dashboard, :show?
      @preset = params[:preset].presence
      @start_date = params[:start_date].presence
      @end_date = params[:end_date].presence
      @page = [params[:page].to_i, 1].max
      @churn = ::Admin::Crm::ChurnReport.new(
        preset: @preset, start_date: @start_date, end_date: @end_date, page: @page
      ).as_json
    end
  end
end
